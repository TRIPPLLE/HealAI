import requests

def get_hospitals_overpass(lat, lon):
    overpass_url = "http://overpass-api.de/api/interpreter"
    overpass_query = f"""
    [out:json];
    (
      node["amenity"="hospital"](around:5000, {lat}, {lon});
      node["amenity"="clinic"](around:5000, {lat}, {lon});
    );
    out center 5;
    """
    response = requests.get(overpass_url, params={'data': overpass_query})
    data = response.json()
    
    hospitals = []
    for element in data.get('elements', []):
        tags = element.get('tags', {})
        name = tags.get('name', 'Unnamed Hospital/Clinic')
        hospitals.append(name)
        
    return hospitals

print(get_hospitals_overpass(19.0760, 72.8777))
