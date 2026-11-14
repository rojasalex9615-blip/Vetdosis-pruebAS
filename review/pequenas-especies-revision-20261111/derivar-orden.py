# Deriva el orden de aplicacion a partir de las cadenas de runners de
# supabase/tests. Solo lee archivos del repositorio: no toca ninguna base.
# Uso: python3 review/pequenas-especies-revision-20261111/derivar-orden.py
import re,pathlib,itertools,collections,json
root=pathlib.Path(__file__).resolve().parents[2]
tests=root/'supabase/tests'
def sqls(line): return re.findall(r'supabase/(?:proposed|migrations|adaptations|tests)/[A-Za-z0-9_.]+\.sql',line)
def expand(runner,extra,depth=0):
    if depth>20: return extra
    txt=(root/runner).read_text().replace('\\\n',' ')
    nxt=None;toks=[]
    for line in txt.splitlines():
        s=line.strip()
        if s.startswith('#') or not s: continue
        m=re.search(r'bash (supabase/tests/run_[A-Za-z0-9_]+\.sh)(.*)',s)
        if m and (root/m.group(1)).exists():
            nxt=m.group(1);toks=[t for t in sqls(m.group(2))];break
    own=[]
    for line in txt.splitlines():
        s=line.strip()
        if s.startswith('#'): continue
        if nxt and ('bash '+nxt) in s: continue
        own+=sqls(s)
    if nxt is None: return own+extra
    return expand(nxt,toks+extra,depth+1)
chains={}
for r in sorted(tests.glob('run_*.sh')):
    rel='supabase/tests/'+r.name
    try: chains[rel]=expand(rel,[])
    except Exception as e: chains[rel]=[]
# precedence constraints over deployable files only
def deployable(f):
    n=pathlib.Path(f).name
    return '/tests/' not in f and not n.startswith('existing_')
pairs=collections.Counter(); nodes=set(); conflict=[]
for rel,fs in chains.items():
    d=[]
    for f in fs:
        if deployable(f) and f not in d: d.append(f)
    nodes|=set(d)
    for a,b in itertools.combinations(d,2): pairs[(a,b)]+=1
for (a,b),n in list(pairs.items()):
    if pairs.get((b,a)): conflict.append((a,b))
print('nodos:',len(nodes),'restricciones:',len(pairs),'ciclos pares:',len(set(map(frozenset,conflict))))
# topo sort, stable by (prefix number, name)
def key(f):
    n=pathlib.Path(f).name
    m=re.match(r'(\d+)',n)
    return (int(m.group(1)) if m else 999, n)
indeg={n:0 for n in nodes}; adj=collections.defaultdict(set)
for (a,b) in pairs:
    if pairs.get((b,a)): continue
    if b not in adj[a]: adj[a].add(b); indeg[b]+=1
import heapq
h=[(key(n),n) for n in nodes if indeg[n]==0]; heapq.heapify(h); out=[]
while h:
    _,n=heapq.heappop(h); out.append(n)
    for m in sorted(adj[n]):
        indeg[m]-=1
        if indeg[m]==0: heapq.heappush(h,(key(m),m))
print('ordenados:',len(out),'de',len(nodes))
for i,f in enumerate(out,1): print(f'{i:3} {f}')
# which runner covers each of the 28 strays
stray=['10_identity','12A_terms','12B_platform','12C_privacy','13Q_','13R_','13S_','13T_','13U_','13V_','13Y_','14A_','14B_','14C_','14E_commission','14G_sale','14H_supplier','14I_clinic_contact','14J_clients','14K_client_loyalty','14L_clinic_prod','14M_','14N_','14O_','14P_','14Q_','15J_','15M_']
print('\nCobertura de las propuestas sueltas:')
for s in stray:
    rs=[r for r,fs in chains.items() if any(s in f for f in fs)]
    print(f'  {s:22} -> {", ".join(pathlib.Path(x).name for x in rs) or "SIN RUNNER"}')
