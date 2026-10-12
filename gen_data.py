"""Generates the synthetic Indian retail dataset used in Project 1 (raw + cleaned)."""
import numpy as np, pandas as pd, json
rng = np.random.default_rng(42)

regions = {
 "North":  ["Delhi","Punjab","Haryana","Uttar Pradesh"],
 "South":  ["Karnataka","Tamil Nadu","Telangana","Kerala"],
 "West":   ["Maharashtra","Gujarat","Rajasthan","Goa"],
 "East":   ["West Bengal","Odisha","Bihar","Assam"],
 "Central":["Madhya Pradesh","Chhattisgarh","Jharkhand","Uttarakhand"],
}
cities = {"Delhi":["New Delhi","Dwarka"],"Punjab":["Ludhiana","Amritsar"],"Haryana":["Gurugram","Faridabad"],
 "Uttar Pradesh":["Lucknow","Noida","Kanpur"],"Karnataka":["Bengaluru","Mysuru","Hubballi"],
 "Tamil Nadu":["Chennai","Coimbatore","Madurai"],"Telangana":["Hyderabad","Warangal"],"Kerala":["Kochi","Thiruvananthapuram"],
 "Maharashtra":["Mumbai","Pune","Nagpur"],"Gujarat":["Ahmedabad","Surat","Vadodara"],"Rajasthan":["Jaipur","Jodhpur"],"Goa":["Panaji","Margao"],
 "West Bengal":["Kolkata","Siliguri"],"Odisha":["Bhubaneswar","Cuttack"],"Bihar":["Patna","Gaya"],"Assam":["Guwahati","Dibrugarh"],
 "Madhya Pradesh":["Bhopal","Indore"],"Chhattisgarh":["Raipur","Bilaspur"],"Jharkhand":["Ranchi","Jamshedpur"],"Uttarakhand":["Dehradun","Haridwar"]}
state_region = {s:r for r,ss in regions.items() for s in ss}
state_w = {s:w for s,w in zip(state_region, rng.dirichlet(np.ones(20)*3))}
for s in ["Maharashtra","Karnataka","Delhi","Tamil Nadu","Telangana"]: state_w[s]*=2
tot=sum(state_w.values()); state_w={k:v/tot for k,v in state_w.items()}

subcat = {
 "Chairs":("Furniture",.25,4500,18000,"mid"), "Tables":("Furniture",.20,8000,32000,"high"),
 "Bookcases":("Furniture",.22,6000,22000,"mid"), "Furnishings":("Furniture",.35,500,4000,"low"),
 "Binders":("Office Supplies",.40,150,900,"high"), "Paper":("Office Supplies",.45,120,1500,"low"),
 "Storage":("Office Supplies",.28,800,6500,"mid"), "Art":("Office Supplies",.38,100,1200,"low"),
 "Labels":("Office Supplies",.42,60,500,"low"),
 "Phones":("Technology",.22,9000,70000,"mid"), "Accessories":("Technology",.35,400,6000,"low"),
 "Copiers":("Technology",.30,25000,120000,"low"), "Machines":("Technology",.18,15000,90000,"high"),
}
adj = ["Classic","Pro","Eco","Prime","Ultra","Smart","Elite","Basic","Compact","Deluxe"]
products=[]; pid=1
for sc,(cat,m,lo,hi,dp) in subcat.items():
    for i in range(5):
        price=round(float(np.exp(rng.uniform(np.log(lo),np.log(hi)))),-1)
        products.append(dict(product_id=f"PRD-{pid:04d}",category=cat,sub_category=sc,
            product_name=f"{adj[(pid+i)%10]} {(sc[:-3]+'y') if sc.endswith('ies') else (sc[:-1] if sc.endswith('s') else sc)} {chr(65+i)}{pid}",
            list_price=price,base_margin=m,dprof=dp)); pid+=1
prod=pd.DataFrame(products)

first=["Aarav","Vivaan","Aditya","Ananya","Diya","Ishaan","Kavya","Rohan","Sneha","Arjun","Meera","Karthik","Priya","Rahul","Neha",
 "Siddharth","Pooja","Vikram","Anjali","Manish","Divya","Nikhil","Shreya","Aman","Tanvi","Harsh","Ritu","Varun","Isha","Gaurav"]
last=["Sharma","Verma","Reddy","Nair","Iyer","Patel","Gupta","Singh","Das","Mehta","Joshi","Kulkarni","Rao","Bose","Chatterjee","Menon","Khan","Shetty","Mishra","Pillai"]
N_CUST=900
states=list(state_w); sp=np.array([state_w[s] for s in states])
cust=pd.DataFrame({
 "customer_id":[f"CUST-{i:04d}" for i in range(1,N_CUST+1)],
 "customer_name":[f"{rng.choice(first)} {rng.choice(last)}" for _ in range(N_CUST)],
 "segment":rng.choice(["Consumer","Corporate","Home Office"],N_CUST,p=[.52,.30,.18]),
 "state":rng.choice(states,N_CUST,p=sp)})
cust["region"]=cust.state.map(state_region)
cust["city"]=[rng.choice(cities[s]) for s in cust.state]
cust["w"]=rng.pareto(2.2,N_CUST)+0.3; cust["w"]/=cust.w.sum()

dates=pd.date_range("2023-01-01","2025-12-31")
season=np.array([0.80,0.78,0.88,0.90,0.95,0.92,0.90,1.00,1.05,1.30,1.45,1.25])
year_g={2023:1.0,2024:1.30,2025:1.62}
dw=np.array([season[d.month-1]*year_g[d.year]*(1.12 if d.dayofweek>=5 else 1.0) for d in dates]); dw/=dw.sum()
N_ORD=4300
od=np.sort(rng.choice(dates,N_ORD,p=dw))
ship_modes=["Same Day","First Class","Second Class","Standard Class"]
rows=[]
disc_levels=np.array([0,.05,.10,.15,.20,.30,.40,.50])
dprob={"low":[.55,.15,.12,.08,.06,.03,.01,0],"mid":[.38,.12,.14,.10,.12,.08,.04,.02],"high":[.20,.06,.10,.10,.16,.18,.12,.08]}
prod_w=np.exp(rng.normal(0,.5,len(prod)))*prod.category.map({'Technology':0.22,'Furniture':0.9,'Office Supplies':4.5}).values; prod_w/=prod_w.sum()
for i,d in enumerate(od):
    oid=f"ORD-{pd.Timestamp(d).year}-{i+1:05d}"
    c=cust.iloc[rng.choice(N_CUST,p=cust.w.values)]
    sm=rng.choice(ship_modes,p=[.06,.15,.20,.59])
    days={"Same Day":0,"First Class":rng.integers(1,3),"Second Class":rng.integers(2,5),"Standard Class":rng.integers(4,9)}[sm]
    if c.region=="Central" and rng.random()<.35: days+=rng.integers(2,5)
    n_lines=rng.choice([1,2,3,4,5],p=[.40,.30,.18,.08,.04])
    for p_i in rng.choice(len(prod),n_lines,replace=False,p=prod_w):
        p=prod.iloc[p_i]
        qty=int(rng.choice([1,2,3,4,5,6,7],p=[.30,.28,.20,.10,.06,.04,.02]))
        dp=np.array(dprob[p.dprof],float)
        if c.region=="Central": dp=dp*np.array([.7,.8,1,1.1,1.2,1.5,1.8,2.0])
        if pd.Timestamp(d).month in (10,11): dp=dp*np.array([.8,1,1,1.1,1.2,1.3,1.3,1.3])
        dp/=dp.sum(); disc=float(rng.choice(disc_levels,p=dp))
        gross=p.list_price*qty*rng.uniform(.97,1.03)
        sales=round(gross*(1-disc),2)
        profit=round(gross*(p.base_margin+rng.normal(0,.02)-disc),2)
        rows.append([oid,pd.Timestamp(d),pd.Timestamp(d)+pd.Timedelta(days=int(days)),sm,c.customer_id,c.customer_name,c.segment,
            c.region,c.state,c.city,p.product_id,p.category,p.sub_category,p.product_name,sales,qty,disc,profit])
cols=["Order ID","Order Date","Ship Date","Ship Mode","Customer ID","Customer Name","Segment","Region","State","City",
      "Product ID","Category","Sub-Category","Product Name","Sales","Quantity","Discount","Profit"]
clean=pd.DataFrame(rows,columns=cols)
print(clean.shape, clean.Sales.sum(), clean.Profit.sum())

raw=clean.copy()
raw["Order Date"]=raw["Order Date"].dt.strftime("%d-%m-%Y"); raw["Ship Date"]=raw["Ship Date"].dt.strftime("%d-%m-%Y")
log={}
dup=raw.sample(int(len(raw)*.02),random_state=1); raw=pd.concat([raw,dup]).reset_index(drop=True); log["exact duplicate rows"]=len(dup)
i2=rng.choice(len(raw),int(len(raw)*.05),replace=False)
raw.loc[i2,"Region"]=[rng.choice([r.lower(),r.upper(),f" {r} "]) for r in raw.loc[i2,"Region"]]; log["inconsistent Region text (case/spaces)"]=len(i2)
i3=rng.choice(len(raw),int(len(raw)*.03),replace=False)
raw.loc[i3,"Segment"]=[f"{s.upper()} " for s in raw.loc[i3,"Segment"]]; log["inconsistent Segment text"]=len(i3)
i4=rng.choice(len(raw),int(len(raw)*.04),replace=False)
raw.loc[i4,"Customer Name"]=[f"  {n.lower()}" for n in raw.loc[i4,"Customer Name"]]; log["customer names with spaces/lowercase"]=len(i4)
i5=rng.choice(len(raw),int(len(raw)*.012),replace=False); raw.loc[i5,"City"]=np.nan; log["missing City"]=len(i5)
i6=rng.choice(len(raw),25,replace=False)
raw.loc[i6,"Ship Date"]=raw.loc[i6,"Order Date"].apply(lambda x:(pd.to_datetime(x,format="%d-%m-%Y")-pd.Timedelta(days=3)).strftime("%d-%m-%Y")); log["ship date earlier than order date"]=len(i6)
i7=rng.choice(len(raw),12,replace=False); raw.loc[i7,"Quantity"]=0; log["quantity = 0 (invalid)"]=len(i7)
i8=rng.choice(len(raw),30,replace=False); raw.loc[i8,"Discount"]=raw.loc[i8,"Discount"]*100; log["discount stored as 20 instead of 0.20"]=len(i8)
raw=raw.sample(frac=1,random_state=5).reset_index(drop=True)
raw.to_csv("data/retail_sales_raw.csv",index=False)
json.dump({k:int(v) for k,v in log.items()},open("data/raw_issue_log.json","w"),indent=1)
clean.to_csv("data/_clean_truth.csv",index=False)
prod.drop(columns=["dprof"]).to_csv("data/_products.csv",index=False)
print(log, len(raw))
