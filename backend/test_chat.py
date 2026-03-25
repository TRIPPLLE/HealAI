import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from main import find_nearby_hospitals

print("Testing Places API:")
print(find_nearby_hospitals(37.7749, -122.4194))

