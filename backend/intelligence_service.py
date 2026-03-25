import feedparser
import requests
from bs4 import BeautifulSoup
from datetime import datetime
import re
from typing import List, Dict

class IntelligenceService:
    def __init__(self, supabase_client):
        self.supabase = supabase_client
        self.sources = {
            "WHO": "https://www.who.int/rss-feeds/news-english.xml",
            "CDC": "https://tools.cdc.gov/api/v2/resources/media/132.rss"
        }

    def fetch_latest_intelligence(self):
        """Main entry point for the Scraper and NLP Agents."""
        all_entries = []
        for source_name, url in self.sources.items():
            print(f"Scraper Agent: Fetching from {source_name}...")
            entries = self._scrape_rss(source_name, url)
            processed = self._nlp_process_entries(entries)
            all_entries.extend(processed)
        
        # Save to database
        if all_entries:
            print(f"Intelligence Agent: Saving {len(all_entries)} new insights...")
            self.supabase.table("global_health_intelligence").upsert(
                all_entries, on_conflict="title"
            ).execute()
        
        return all_entries

    def _scrape_rss(self, source: str, url: str) -> List[Dict]:
        feed = feedparser.parse(url)
        results = []
        for entry in feed.entries[:50]: # Increased to 50 for 'doomscrolling'
            results.append({
                "source": source,
                "title": entry.title,
                "summary": self._clean_html(entry.summary if 'summary' in entry else entry.description),
                "published_at": entry.published if 'published' in entry else datetime.now().isoformat(),
                "url": entry.link
            })
        return results

    def _clean_html(self, html: str) -> str:
        if not html: return ""
        soup = BeautifulSoup(html, "html.parser")
        return soup.get_text()

    def _nlp_process_entries(self, entries: List[Dict]) -> List[Dict]:
        """NLP Agent: Classifies and summarizes raw entries."""
        processed = []
        for entry in entries:
            # Combine title and summary for analysis
            text = f"{entry['title']} {entry['summary']}".lower()
            
            # 1. Classification (Risk Level & Category)
            category, risk = self._classify_text(text)
            
            # 2. Geographic Relevance
            geo = self._extract_geographic_relevance(text)
            
            # 3. Defensive Actions (Rule-based suggestions)
            actions = self._suggest_actions(category, risk)
            
            processed.append({
                "source": entry['source'],
                "title": entry['title'],
                "summary": entry['summary'],
                "risk_level": risk,
                "category": category,
                "geographic_relevance": geo,
                "preventive_actions": actions,
                "published_at": entry['published_at'],
                "metadata": {"url": entry['url']}
            })
        return processed

    def _classify_text(self, text: str):
        # Category Mapping
        categories = {
            "Outbreak": ["outbreak", "virus", "infection", "case", "pandemic", "spread", "flu", "covid"],
            "Environmental": ["heatwave", "pollution", "climate", "air quality", "water", "flood", "drought"],
            "Advisory": ["guideline", "recommendation", "advice", "warning", "update", "policy"]
        }
        
        # Risk Mapping
        risks = {
            "high": ["emergency", "deadly", "crisis", "critical", "danger", "urgent", "death"],
            "medium": ["warning", "risk", "concern", "monitor", "increasing"],
            "low": ["update", "information", "regular", "routine"]
        }

        detected_cat = "General"
        for cat, keywords in categories.items():
            if any(k in text for k in keywords):
                detected_cat = cat
                break
        
        detected_risk = "low"
        for risk, keywords in risks.items():
            if any(k in text for k in keywords):
                detected_risk = risk
                break
        
        # Override: Outbreaks are usually medium-high
        if detected_cat == "Outbreak" and detected_risk == "low":
            detected_risk = "medium"
            
        return detected_cat, detected_risk

    def _extract_geographic_relevance(self, text: str) -> str:
        # Simple extraction for major regions/countries
        regions = ["Africa", "Asia", "Europe", "Americas", "Pacific", "Global"]
        for r in regions:
            if r.lower() in text:
                return r
        return "Global"

    def _suggest_actions(self, category: str, risk: str) -> str:
        if risk == "high" and category == "Outbreak":
            return "Wear masks, avoid crowded areas, and check for vaccination eligibility."
        elif category == "Environmental":
            return "Stay indoors, stay hydrated, and monitor local air/water quality reports."
        elif category == "Advisory":
            return "Review updated health guidelines and consult your primary physician if concerned."
        return "Stay informed through trusted health sources and maintain regular hygiene."
