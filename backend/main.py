from grpc import StatusCode
import google.generativeai as genai
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
from datetime import datetime, time, timedelta
from typing import List, Optional, Dict
from supabase import create_client, Client

app = FastAPI(title="Health Monitoring API")

@app.get("/")
def root():
    return {"status": "ok", "message": "HealAI API is running"}

# Supabase setup
SUPABASE_URL = "https://xowqknkxnbalzgapohoo.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhvd3Frbmt4bmJhbHpnYXBvaG9vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5Njc2OTEsImV4cCI6MjA4OTU0MzY5MX0.dPUU8ffHfJRD-aiAvj9kkNqH5TSi88dpGOkBSPidGZQ"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Gemini setup
GEMINI_API_KEY = "AIzaSyDTK0BwsQk05nxPmnAavcdz1sE25lkbnXc"
genai.configure(api_key=GEMINI_API_KEY)
generation_config = {
  "temperature": 0.7,
  "top_p": 0.95,
  "top_k": 64,
  "max_output_tokens": 1024,
  "response_mime_type": "text/plain",
}
gemini_model = genai.GenerativeModel(
  model_name="gemini-2.5-flash",
  generation_config=generation_config,
)

class HealthData(BaseModel):
    user_id: str
    steps: int
    heart_rate: float
    sleep_hours: float
    timestamp: datetime

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    user_id: str
    message: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    history: List[ChatMessage] = []

class Alert(BaseModel):
    user_id: str
    type: str
    message: str
    timestamp: datetime

class Medication(BaseModel):
    user_id: str
    name: str
    dosage: str
    frequency: str
    scheduled_times: List[str] # Format 'HH:MM'
    days_of_week: Optional[List[int]] = None # 1=Mon, 7=Sun

class AdherenceLog(BaseModel):
    user_id: str
    medication_id: str
    scheduled_time: datetime
    status: str # 'taken', 'missed', 'skipped'
    actual_intake_time: Optional[datetime] = None

@app.post("/health-data")
def receive_health_data(data: HealthData):
    # Rule-based analysis
    alerts = []
    
    if data.heart_rate > 100:
        alerts.append({
            "user_id": data.user_id,
            "type": "High Heart Rate",
            "message": f"Heart rate is high: {data.heart_rate} bpm",
            "timestamp": data.timestamp
        })
        
    if data.sleep_hours < 6:
        alerts.append({
            "user_id": data.user_id,
            "type": "Low Sleep",
            "message": f"Sleep duration is low: {data.sleep_hours} hours",
            "timestamp": data.timestamp
        })
        
    if data.steps < 3000:
        alerts.append({
            "user_id": data.user_id,
            "type": "Low Activity",
            "message": f"Steps are low: {data.steps} steps",
            "timestamp": data.timestamp
        })

    # Save data to Supabase
    data_record = {
        "user_id": data.user_id,
        "steps": data.steps,
        "heart_rate": data.heart_rate,
        "sleep_hours": data.sleep_hours,
        "timestamp": data.timestamp.isoformat()
    }
    supabase.table("health_metrics").insert(data_record).execute()
    
    # Save alerts to Supabase
    if alerts:
        supabase.table("alerts").insert(alerts).execute()
    
    return {"status": "success", "alerts": alerts}

@app.get("/health-summary/{user_id}")
def get_health_summary(user_id: str):
    # Get latest metric
    metrics_response = supabase.table("health_metrics") \
        .select("*") \
        .eq("user_id", user_id) \
        .order("timestamp", desc=True) \
        .limit(1) \
        .execute()
    
    latest = metrics_response.data[0] if metrics_response.data else None
    
    # Get latest alerts
    alerts_response = supabase.table("alerts") \
        .select("*") \
        .eq("user_id", user_id) \
        .order("timestamp", desc=True) \
        .limit(5) \
        .execute()
    
    alerts = alerts_response.data
    
    if not latest:
        return {"user_id": user_id, "data": None, "alerts": []}
        
    return {
        "user_id": user_id,
        "latest_data": latest,
        "recent_alerts": alerts
    }

@app.get("/health-history/{user_id}")
def get_health_history(user_id: str, days: int = 7):
    # Get last N days of data
    response = supabase.table("health_metrics") \
        .select("*") \
        .eq("user_id", user_id) \
        .order("timestamp", desc=True) \
        .limit(days) \
        .execute()
    
    return {
        "user_id": user_id,
        "history": response.data
    }

# --- Medication Pillar Endpoints ---

@app.post("/medications")
def add_medication(med: Medication):
    data = {
        "user_id": med.user_id,
        "name": med.name,
        "dosage": med.dosage,
        "frequency": med.frequency,
        "scheduled_times": med.scheduled_times,
        "days_of_week": med.days_of_week
    }
    response = supabase.table("medications").insert(data).execute()
    return {"status": "success", "data": response.data}

@app.get("/medications/{user_id}")
def get_medications(user_id: str):
    response = supabase.table("medications").select("*").eq("user_id", user_id).execute()
    return {"medications": response.data}

@app.post("/adherence")
def log_adherence(log: AdherenceLog):
    try:
        data = log.dict()
        # Convert datetimes to ISO strings for Supabase
        data['scheduled_time'] = data['scheduled_time'].isoformat()
        if data['actual_intake_time']:
            data['actual_intake_time'] = data['actual_intake_time'].isoformat()
            
        print(f"Upserting adherence: {data}")
        response = supabase.table("medication_adherence") \
            .upsert(data, on_conflict="user_id,medication_id,scheduled_time") \
            .execute()
        
        # Analyze adherence after logging
        analyze_adherence(log.user_id)
        return {"status": "success", "data": response.data}
    except Exception as e:
        print(f"Adherence Log Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/adherence-analysis/{user_id}")
def get_adherence_analysis(user_id: str):
    # Fetch last 7 days of logs
    seven_days_ago = (datetime.now() - timedelta(days=7)).isoformat()
    logs_response = supabase.table("medication_adherence") \
        .select("*") \
        .eq("user_id", user_id) \
        .gte("scheduled_time", seven_days_ago) \
        .order("scheduled_time", desc=True) \
        .execute()
    
    logs = logs_response.data
    if not logs:
        return {"user_id": user_id, "status": "No data", "analysis": {}}

    missed_count = sum(1 for log in logs if log['status'] == 'missed')
    total_count = len(logs)
    adherence_rate = ((total_count - missed_count) / total_count) * 100 if total_count > 0 else 100

    # Pattern Detection: Irregular timing
    irregular_timing = False
    timing_diffs = []
    for log in logs:
        if log['status'] == 'taken' and log['actual_intake_time'] and log['scheduled_time']:
            try:
                # Making ISO parsing more robust for different microsecond lengths
                actual_str = log['actual_intake_time'].replace('Z', '+00:00')
                sched_str = log['scheduled_time'].replace('Z', '+00:00')
                
                # Manual fix for potential microsecond length issues (e.g. 4 or 7 digits)
                def clean_iso(s):
                    if '.' in s and '+' in s:
                        parts = s.split('.')
                        time_part, micro_part = parts[0], parts[1].split('+')[0]
                        offset = s.split('+')[1]
                        return f"{time_part}.{micro_part.ljust(6, '0')[:6]}+{offset}"
                    return s

                actual = datetime.fromisoformat(clean_iso(actual_str))
                sched = datetime.fromisoformat(clean_iso(sched_str))
                
                diff = abs((actual - sched).total_seconds()) / 60 # minutes
                timing_diffs.append(diff)
                if diff > 60: # More than 1 hour off
                    irregular_timing = True
            except Exception as e:
                print(f"Error parsing date: {e}")
                continue

    avg_timing_diff = sum(timing_diffs) / len(timing_diffs) if timing_diffs else 0

    analysis = {
        "adherence_rate": round(adherence_rate, 2),
        "missed_last_7_days": missed_count,
        "irregular_timing": irregular_timing,
        "avg_timing_delay_mins": round(avg_timing_diff, 1)
    }

    return {"user_id": user_id, "analysis": analysis, "logs": logs}

def analyze_adherence(user_id: str):
    """Internal function to generate intelligent alerts based on adherence patterns."""
    analysis_res = get_adherence_analysis(user_id)
    analysis = analysis_res.get("analysis", {})
    
    alerts = []
    if analysis.get("missed_last_7_days", 0) >= 2:
        alerts.append({
            "user_id": user_id,
            "type": "Medication Non-Adherence",
            "message": f"You missed your medication {analysis['missed_last_7_days']} times this week. Consistency is key for treatment efficacy.",
            "timestamp": datetime.now().isoformat()
        })
    
    if analysis.get("irregular_timing", False):
        alerts.append({
            "user_id": user_id,
            "type": "Irregular Intake",
            "message": "Your medication intake timing is inconsistent (avg delay: {} mins). Try to take it at the same time each day.".format(analysis.get("avg_timing_delay_mins")),
            "timestamp": datetime.now().isoformat()
        })

    if alerts:
        supabase.table("alerts").insert(alerts).execute()

from intelligence_service import IntelligenceService
from fastapi import BackgroundTasks

# Initialize Intelligence Service
intel_service = IntelligenceService(supabase)

@app.get("/intelligence/latest")
@app.head("/intelligence/latest")
def get_latest_intelligence():
    response = supabase.table("global_health_intelligence") \
        .select("*") \
        .order("published_at", desc=True) \
        .limit(50) \
        .execute()
    return {"intelligence": response.data}

@app.on_event("startup")
async def startup_event():
    """Trigger intelligence fetch on startup."""
    print("Startup: Triggering global health intelligence fetch...")
    # Run in background to not block startup
    import asyncio
    asyncio.create_task(asyncio.to_thread(intel_service.fetch_latest_intelligence))

@app.post("/intelligence/refresh")
def refresh_intelligence(background_tasks: BackgroundTasks):
    """Manually trigger or schedule a refresh of global health data."""
    background_tasks.add_task(intel_service.fetch_latest_intelligence)
    return {"status": "refresh_started"}

# --- End Medication Pillar ---

# --- AI Chat Endpoint ---
def find_nearby_hospitals(latitude: float, longitude: float) -> str:
    """Finds hospitals near the given latitude and longitude coordinates."""
    import requests
    overpass_url = "http://overpass-api.de/api/interpreter"
    overpass_query = f"""
    [out:json];
    (
      node["amenity"="hospital"](around:5000, {latitude}, {longitude});
      node["amenity"="clinic"](around:5000, {latitude}, {longitude});
    );
    out center 5;
    """
    try:
        headers = {"User-Agent": "HealAI_App/1.0 (test_app_user@example.com)"}
        response = requests.get(overpass_url, params={'data': overpass_query}, headers=headers, timeout=15)
        data = response.json()
        hospitals = []
        for element in data.get('elements', []):
            tags = element.get('tags', {})
            name = tags.get('name', 'Unnamed Healthcare Facility')
            # Exclude unnamed nodes if preferred, but sometimes they exist
            if name == 'Unnamed Healthcare Facility':
                continue
            street = tags.get('addr:street', '')
            city = tags.get('addr:city', '')
            address = f"{street}, {city}".strip(", ")
            info = f"- {name}" + (f" ({address})" if address else "")
            hospitals.append(info)
        
        if hospitals:
            return "Found the following real nearby healthcare facilities based on OSM data:\n" + "\n".join(hospitals)
        return "No hospitals or clinics found within 5km of the user's specific location."
    except Exception as e:
        return f"Failed to fetch local hospitals: {str(e)}"

@app.post("/chat")
def chat_with_ai(req: ChatRequest):
    try:
        # Construct history in Gemini format
        formatted_history = []
        for msg in req.history:
            formatted_history.append({
                "role": "user" if msg.role == "user" else "model",
                "parts": [{"text": msg.content}]
            })
        
        chat_session = gemini_model.start_chat(history=formatted_history)
        
        msg_lower = req.message.lower()
        if ("hospital" in msg_lower or "clinic" in msg_lower or "doctor" in msg_lower or "emergency" in msg_lower or "beside" in msg_lower or "near" in msg_lower) and req.latitude and req.longitude:
            nearby_info = find_nearby_hospitals(req.latitude, req.longitude)
            prompt = f"The user asked about nearby hospitals/clinics/healthcare. Here is data fetched hyper-locally based on their exact GPS coordinates:\n{nearby_info}\n\nPlease summarize this information nicely for the user and present to them exactly what was found. User's query: {req.message}"
        else:
            base_prompt = "You are HealAI, a helpful and empathetic health assistant AI."
            if not req.history:
                prompt = f"{base_prompt}\nUser's question: {req.message}"
            else:
                prompt = req.message
            
        print("Final prompt to Gemini:", prompt)
        response = chat_session.send_message(prompt)
        
        return {"status": "success", "response": response.text}
    except Exception as e:
        print(f"Chat Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
# --- End AI Chat ---

if __name__ == "__main__":
    import uvicorn
    # On startup, trigger a refresh in the background
    # Note: In production, use a proper scheduler like Celery or APScheduler
    uvicorn.run(app, host="0.0.0.0", port=8000)
