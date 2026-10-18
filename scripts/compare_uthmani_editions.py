#!/usr/bin/env python3
"""Non-destructive offline comparison. This cannot approve sacred content."""
import argparse, hashlib, json, sys
from pathlib import Path
PRIMARY_SHA="f2f03c415ea50f8493d2058ec67a90257333abe3"
SECONDARY_SHA="87cdfd0096fa3057dbf7904f925608cd2e1d100e"
class IntegrityError(ValueError): pass

def git_sha(raw):
    return hashlib.sha1(b"blob "+str(len(raw)).encode()+bytes([0])+raw).hexdigest()

def parse_primary(raw):
    parsed={}
    for line in raw.decode("utf-8-sig").splitlines():
        if not line or line.startswith("#"):continue
        p=line.split("|",2)
        if len(p)!=3:raise IntegrityError("Malformed primary line")
        key=(int(p[0]),int(p[1]))
        if key in parsed or not p[2]:raise IntegrityError("Duplicate or empty verse")
        parsed[key]=p[2]
    return parsed

def parse_secondary(raw,refs):
    lines=[s for s in raw.decode("utf-8-sig").splitlines() if s and not s.startswith("#")]
    if len(lines)!=len(refs):raise IntegrityError("Secondary corpus count mismatch")
    return dict(zip(refs,lines))

def compare(a,b):
    if a.keys()!=b.keys() or len(a)!=6236:raise IntegrityError("Expected 6236 aligned verses")
    exact=0;tatweel=0;pending=[]
    for ref,first in a.items():
        second=b[ref]
        if first==second:exact+=1
        elif first.replace("\u0640","")==second.replace("\u0640",""):tatweel+=1
        else:pending.append(f"{ref[0]}:{ref[1]}")
    return {"exact":exact,"tatweel_only_diagnostic":tatweel,
      "remaining_count":len(pending),"remaining_references":pending,
      "text_altered":False,"scholarly_approval":"PENDING","release_allowed":False}

def audit(primary_file,secondary_file,catalog_file):
    raw1=primary_file.read_bytes();raw2=secondary_file.read_bytes()
    if git_sha(raw1)!=PRIMARY_SHA or git_sha(raw2)!=SECONDARY_SHA:
        raise IntegrityError("Pinned source SHA mismatch")
    rows=[r.split("|") for r in catalog_file.read_text(encoding="utf-8").splitlines() if r]
    expected={(int(r[0]),n) for r in rows for n in range(1,int(r[2])+1)}
    if len(rows)!=114 or len(expected)!=6236:raise IntegrityError("Invalid Surah catalog")
    a=parse_primary(raw1)
    if set(a)!=expected or list(a)!=sorted(a):raise IntegrityError("Primary verse references invalid")
    b=parse_secondary(raw2,list(a))
    result=compare(a,b)
    result.update({"surahs":114,"ayahs":6236,"first_git_sha1":git_sha(raw1),
      "second_git_sha1":git_sha(raw2),"first_sha256":hashlib.sha256(raw1).hexdigest(),
      "second_sha256":hashlib.sha256(raw2).hexdigest(),
      "official_tanzil_download_comparison":"PENDING",
      "independent_reviewer_one":"PENDING","independent_reviewer_two":"PENDING"})
    return result

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--primary",type=Path,required=True)
    p.add_argument("--secondary",type=Path,required=True)
    p.add_argument("--catalog",type=Path,required=True)
    p.add_argument("--report",type=Path)
    args=p.parse_args()
    try:
        result=audit(args.primary,args.secondary,args.catalog)
        data=json.dumps(result,ensure_ascii=False,indent=2)+"\n"
        if args.report:
            args.report.parent.mkdir(parents=True,exist_ok=True)
            args.report.write_text(data,encoding="utf-8")
        print(data);return 0
    except (ValueError,OSError) as err:
        print("FAILED: "+str(err),file=sys.stderr);return 1
if __name__=="__main__":sys.exit(main())
