from pathlib import Path
import subprocess,re,json,hashlib,csv,argparse
parser=argparse.ArgumentParser(description='Extrae tablas numéricas de las guías oficiales; requiere pdftotext.')
parser.add_argument('--input-dir',type=Path,required=True)
args=parser.parse_args()
root=args.input_dir
repo=Path(__file__).resolve().parents[2]
SOURCES=[
 ('bovans-cage','Bovans','Bovans Brown','jaula','L6230-1 · sin año impreso','bovans-brown', 'https://www.bovans.com/documents/2579/Bovans_Brown_CS_product_guide_cage_EN_L6230_-1_HyEGkWM.pdf',6),
 ('bovans-floor','Bovans','Bovans Brown','piso','L6230-1 · sin año impreso','bovans-alt','https://www.bovans.com/documents/2577/Bovans_Brown_CS_product_guide_alternative_EN_L6230-1.pdf',6),
 ('hyline-cage','Hy-Line','Hy-Line Brown','jaula','Diciembre 2025','hyline-brown','https://www.hyline.com/filesimages/Hy-Line-Products/Hy-Line-Product-PDFs/Brown/BRN%20STD%20ENG.pdf',4),
 ('hyline-floor','Hy-Line','Hy-Line Brown','piso','Mayo 2026','hyline-alt-full','https://www.hyline.com/filesimages/Hy-Line-Products/Hy-Line-Product-PDFs/Brown/Brown%20Alt/BRN%20ALT%20STD%20ENG.pdf',4),
 ('lohmann-cage-2019','Lohmann','Lohmann Brown-Classic','jaula','Diciembre 2019 · archivo histórico','lohmann-cage-old','https://lohmann-breeders.com/media/2020/07/ManagementGuideLBClassicCage-EN.pdf',15),
 ('lohmann-cage-v01-24','Lohmann','Lohmann Brown-Classic','jaula','08/21_V01-24 · sin año único impreso','lohmann-cage','https://lohmann-breeders.com/files/downloads/MG/Cage/LB_MG_Cage_LB-Classic_EN.pdf',15),
 ('lohmann-floor-2018','Lohmann','Lohmann Brown-Classic','piso','Abril 2018 · archivo histórico','lohmann-alt','https://lohmann-breeders.com/media/2021/03/LTZ_MG_management-systems_EN.pdf',24),
]
def page(name,n):
 return subprocess.check_output(['pdftotext','-f',str(n),'-l',str(n),'-layout',str(root/(name+'.pdf')),'-']).decode()
def nums(line):return re.findall(r'\d+(?:\.\d+)?',line.replace(',',''))
guides=[]
for id,brand,strain,system,edition,name,url,pn in SOURCES:
 rows=[];text=page(name,pn)
 for line in text.splitlines():
  n=nums(line)
  if not re.match(r'^\s*\d+\s',line) or len(n)<3:continue
  w=int(n[0]);r={'week':w,'page':pn}
  if not 1<=w<=20:continue
  if brand=='Bovans':
   if len(n)!=9:continue
   r.update(feedMin=n[3],feedMax=n[4],cumulativeMin=n[5],cumulativeMax=n[6],weightMin=n[7],weightMax=n[8])
  elif brand=='Hy-Line':
   if len(n)<10:continue
   factor=1000 if system=='piso' else 1
   r.update(mortality=n[1],weightMin=n[2],weightMax=n[3],feedMin=n[6],feedMax=n[7],cumulativeMin=str(round(float(n[8])*factor)),cumulativeMax=str(round(float(n[9])*factor)))
   # The merged uniformity cells explicitly span these weeks in the PDF.
   r['uniformityMin']='85' if w<=3 or 7<=w<=16 else '80' if w<=6 else '90'
   r['uniformityQualifier']='>'
  elif id=='lohmann-cage-2019':
   if len(n)!=7:continue
   r.update(weightMin=n[2],weightMax=n[3],feedMin=n[5],feedMax=n[5],cumulativeMin=n[6],cumulativeMax=n[6])
  elif id=='lohmann-cage-v01-24':
   if len(n)!=4:continue
   r.update(weightMin=n[2],weightMax=n[3])
  else:
   if len(n)!=8:continue
   r.update(feedMin=n[1],feedMax=n[1])
  rows.append(r)
 if brand=='Hy-Line':
  # Week 18 belongs to the production table; its mortality restarts at 18.
  # Keep its feed/weight, never carry that mortality into a rearing total.
  for line in page(name,5).splitlines():
   if re.match(r'^\s*18\s',line):
    n=nums(line)
    # Conventional and alternative current PDFs have different column layouts.
    if system=='jaula': r={'week':18,'page':5,'weightMin':n[8],'weightMax':n[9],'feedMin':n[12],'feedMax':n[13]}
    else:
     r={'week':18,'page':5,'weightMin':n[8],'weightMax':n[9],'feedMin':n[10],'feedMax':n[11]}
    if r:rows.append(r)
    break
 if id=='lohmann-floor-2018':
  weights={}
  for line in page(name,22).splitlines():
   n=nums(line)
   if re.match(r'^\s*\d+\s',line) and len(n)==8 and 1<=int(n[0])<=20: weights[int(n[0])]=n[1]
  lights={}
  for line in page(name,15).splitlines():
   n=nums(line)
   if re.match(r'^\s*\d+\s',line) and len(n)==7 and 2<=int(n[0])<=20:lights[int(n[0])]=n[4]
  for r in rows:
   if r['week'] in weights:r.update(weightMin=weights[r['week']],weightMax=weights[r['week']],weightPage=22)
   if r['week'] in lights:r.update(lightMin=lights[r['week']],lightMax=lights[r['week']],lightPage=15)
 assert len(rows)>=17,(id,len(rows),rows)
 assert sorted({r['week'] for r in rows})==list(range(1,len(rows)+1)),(id,'weeks')
 guide={'id':id,'brand':brand,'strain':strain,'system':system,'edition':edition,'url':url,'retrieved':'2026-11-27','sha256':hashlib.sha256((root/(name+'.pdf')).read_bytes()).hexdigest(),'title':strain+' · '+('Management Guide' if brand=='Lohmann' else 'Product Guide' if brand=='Bovans' else 'Performance Standards Guide'), 'notes':[], 'rows':rows}
 if brand=='Lohmann':guide['notes'].append('Las cifras de alimento son orientativas para presupuesto. La guía indica alimentación a libre acceso; no son límites de ración.')
 if id.endswith('2019') or id.endswith('2018'):guide['notes'].append('Edición histórica: se conserva identificada, sin mezclar sus cifras con otras ediciones.')
 if id=='lohmann-cage-v01-24':guide['notes'].append('Esta edición publica peso corporal pero no consumo semanal en la tabla 4. Captura tu consumo o elige otra edición explícitamente.')
 if brand=='Hy-Line':guide['notes'].append('La semana 18, si está incluida, procede de la tabla de producción; no se reutiliza su mortalidad reiniciada para crianza.')
 if id=='lohmann-floor-2018':guide['notes'].append('El programa de luz de la página 15 corresponde a naves cerradas; no se aplica automáticamente a naves abiertas.')
 if id=='hyline-floor':guide['densityReferences']=[{'week':w,'birdsPerM2':str(v),'page':4,'note':'Densidad útil al transferir en la semana indicada; no es densidad para toda la crianza.'} for w,v in [(15,15),(16,14),(17,13),(18,12)]]
 guides.append(guide)
 print(id,len(rows),rows[0],rows[-1])
out={'schemaVersion':1,'guides':guides,'equipmentDefaults':[{'name':name,'basis':'birds','coverage':str(ratio),'source':'Proyecto de crianza aportado por Ale; razón editable, no recomendación del fabricante.'} for name,ratio in [('Vitrolero',60),('Charola de iniciación',60),('Mini tolva',50),('Criadora de gas',800),('Bebedero de campana',80),('Tolva de desarrollo',40)]]}
(repo/'assets/clinical/aviculture/guia_linea.v1.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
with (repo/'docs/product/crianza-postura/guia_linea.csv').open('w') as f:
 writer=csv.DictWriter(f,lineterminator='\n',fieldnames=['guide','brand','system','edition','url','sha256','week','page','feedMin','feedMax','cumulativeMin','cumulativeMax','weightMin','weightMax','weightPage','mortality','uniformityMin','uniformityQualifier','lightMin','lightMax','lightPage']);writer.writeheader()
 for g in guides:
  for r in g['rows']:writer.writerow(dict(guide=g['id'],brand=g['brand'],system=g['system'],edition=g['edition'],url=g['url'],sha256=g['sha256'],**r))
