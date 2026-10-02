import json
from pathlib import Path
P=Path(__file__).resolve().parent.parent
for folder,n in [('remaining-fusions','Scrap_Hybrid'),('remaining-fusions','Rattle_Hauler'),('legendary-production','Rocket_Freight'),('legendary-production','Core_Carrier')]:
 print(n)
 for g in json.loads((P/folder/(n+'.json')).read_text())['parts']:
  if any(k in g['name']for k in ['Cream_Body','Nitrous bottle','Braided nitrous','Side exhaust collector','Cargo launch pod','flux supply','Cargo cooling radiator']):
   print(g['name'],[(round(min(v[i]for v in g['vertices']),2),round(max(v[i]for v in g['vertices']),2))for i in range(3)])
