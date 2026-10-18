#!/usr/bin/env python3
"""Safwa Quran source verification: offline checks and quarantine-only acquisition."""
import argparse
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CAT=ROOT/"assets/data/chapters.tsv"
ACT=ROOT/"assets/data/content_activation.json"
LOCK=ROOT/"config/source_manifest.json"
RELEASE=ROOT/"config/release_policy.json"
QURAN=ROOT/"assets/data/quran_verified.json"
ARABIC=re.compile(r"[\u0600-\u06ff]")
class IntegrityError(ValueError):pass

def catalog():
    data=[]
    for line in CAT.read_text(encoding="utf-8").splitlines():
        number,name,count=line.split("|")
        data.append((int(number),name,int(count)))
    if len(data)!=114 or [x[0] for x in data]!=list(range(1,115)):
        raise IntegrityError("114 ordered Surahs required")
    if not all(name.strip() and count>0 for _,name,count in data):
        raise IntegrityError("Invalid Surah catalog")
    if sum(x[2] for x in data)!=6236:
        raise IntegrityError("Quran verse count must total 6236")
    return data


def audit_review_candidate():
    """Verify the quarantined text and JSON candidate are the same, byte-pinned corpus.
    These checks are NOT a substitute for two independent textual/scholarly reviews.
    """
    source=ROOT/"sources/review_only/tanzil_uthmani_1.1_verbatim.txt"
    candidate=ROOT/"sources/review_only/quran_candidate.json"
    if not source.exists() and not candidate.exists():
        return "NOT_ACQUIRED"
    if not source.exists() or not candidate.exists():
        raise IntegrityError("Incomplete quarantined source pair")
    raw=source.read_bytes()
    manifest=json.loads(LOCK.read_text(encoding="utf-8"))
    got=hashlib.sha1(("blob "+str(len(raw))).encode()+bytes([0])+raw).hexdigest()
    if got!=manifest["mirror_git_blob_sha1"]:
        raise IntegrityError("Pinned original Quran text blob differs")
    if b"Tanzil Quran Text" not in raw:
        raise IntegrityError("Copyright attribution missing from original")
    data=json.loads(candidate.read_text(encoding="utf-8"))
    if data.get("status")!="QUARANTINED_NOT_APPROVED" or data.get("license_url")!=manifest["license"]:
        raise IntegrityError("Quarantine attribution/review status invalid")
    # The original Tanzil copyright text must remain verbatim in all substantial derivatives.
    notice="# PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK"
    original=raw.decode("utf-8-sig")
    if notice not in original:
        raise IntegrityError("Tanzil copyright block missing")
    if data.get("copyright_notice_verbatim")!=original[original.index(notice):]:
        raise IntegrityError("Derived Quran text has lost or changed its exact source copyright block")
    chapters=data["chapters"]
    validate_chapters(chapters,catalog())
    actual=[]
    for line in raw.decode("utf-8-sig").splitlines():
        if line and not line.startswith("#"):
            pair=line.split("|",2)
            if len(pair)!=3: raise IntegrityError("Invalid source line")
            actual.append((int(pair[0]),int(pair[1]),pair[2]))
    copied=[(row["number"],v["number"],v["text"])
            for row in chapters for v in row["verses"]]
    if len(actual)!=6236 or actual!=copied:
        raise IntegrityError("Candidate modified original Quran characters")
    return "SIX_THOUSAND_TWO_HUNDRED_THIRTY_SIX_VERBATIM_MATCHED"

def check():
    counts=catalog()
    audit_review_candidate()
    activation=json.loads(ACT.read_text(encoding="utf-8"))
    policy=json.loads(RELEASE.read_text(encoding="utf-8"))
    if policy.get("brand_rights_confirmed") is not True:
        raise IntegrityError("Brand rights not recorded")
    if activation.get("quran_reader_enabled") is True:
        if activation.get("review_status")!="approved":
            raise IntegrityError("Unreviewed Quran content activated")
        reviews=activation.get("review_evidence",[])
        if len(set(reviews))<2 or not all(isinstance(r,str) and r.strip() for r in reviews):
            raise IntegrityError("Two independent reviews required")
        if not QURAN.exists():
            raise IntegrityError("Activated source missing")
        raw=QURAN.read_bytes()
        if hashlib.sha256(raw).hexdigest()!=activation.get("approved_source_sha256"):
            raise IntegrityError("Approved SHA-256 mismatch")
        chapters=json.loads(raw)["chapters"]
        validate_chapters(chapters,counts)
    elif QURAN.exists():
        raise IntegrityError("Unreviewed Quran text must not be bundled")
    return True

def validate_chapters(chapters,counts):
    if len(chapters)!=114:raise IntegrityError("Expected 114 Surahs")
    for (number,_,expected),chapter in zip(counts,chapters):
        if chapter.get("number")!=number:raise IntegrityError("Wrong chapter order")
        verses=chapter.get("verses",[])
        if len(verses)!=expected:raise IntegrityError("Wrong ayah count for chapter "+str(number))
        for i,v in enumerate(verses,1):
            if v.get("number")!=i or not isinstance(v.get("text"),str) or not ARABIC.search(v["text"]):
                raise IntegrityError("Malformed Arabic verse "+str(number)+":"+str(i))

def release_check():
    check()
    policy=json.loads(RELEASE.read_text(encoding="utf-8"))
    if not all(x is True for x in policy.values()):
        raise IntegrityError("Release blocked: mandatory policy approvals are incomplete")
    if not json.loads(ACT.read_text(encoding="utf-8")).get("quran_reader_enabled"):
        raise IntegrityError("Release blocked: verified Mushaf not activated")
    return True

def acquire(out):
    # This mirror is pinned by Git blob SHA1 and is only a candidate, not independent verification.
    source=json.loads(LOCK.read_text(encoding="utf-8"))
    url=source["mirror"]
    if not url.startswith("https://raw.githubusercontent.com/acfatah/tanzil/"):
        raise IntegrityError("Untrusted acquisition source")
    if out.exists() and any(out.iterdir()):
        raise IntegrityError("Use an empty quarantine directory")
    with urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":"Safwa-Quran-source-audit/0.3"}),timeout=60) as response:
        raw=response.read(3_000_000)
    blob_hash=hashlib.sha1(("blob "+str(len(raw))+"\0").encode()+raw).hexdigest()
    if blob_hash!=source["mirror_git_blob_sha1"]:
        raise IntegrityError("Tanzil mirror content changed; review updated source before use")
    counts=catalog()
    chapters=[{"number":i,"verses":[]} for i in range(1,115)]
    for line in raw.decode("utf-8-sig").splitlines():
        if not line or line.startswith("#"):continue
        parts=line.split("|",2)
        if len(parts)!=3:raise IntegrityError("Unexpected Tanzil txt-2 line")
        number,ayah=int(parts[0]),int(parts[1])
        if not 1<=number<=114:raise IntegrityError("Out of range chapter")
        target=chapters[number-1]["verses"]
        if ayah!=len(target)+1 or not ARABIC.search(parts[2]):
            raise IntegrityError("Out of order or non-Arabic verse")
        target.append({"number":ayah,"text":parts[2]}) # Verbatim: never rewrite Arabic.
    validate_chapters(chapters,counts)
    out.mkdir(parents=True,exist_ok=True)  # Empty pre-created quarantine directories are valid.
    (out/"tanzil_source_verbatim.txt").write_bytes(raw)
    (out/"quran_candidate.json").write_text(json.dumps({"chapters":chapters},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    report={"status":"QUARANTINED_NOT_RELEASE_APPROVED","source_url":url,
        "source_blob_sha1":blob_hash,"source_sha256":hashlib.sha256(raw).hexdigest(),
        "candidate_sha256":hashlib.sha256((out/"quran_candidate.json").read_bytes()).hexdigest(),
        "surahs":len(chapters),"ayahs":sum(len(x["verses"]) for x in chapters),
        "license_url":source["license"],"independent_reviewer_1":"PENDING",
        "independent_reviewer_2":"PENDING","official_source_comparison":"PENDING"}
    (out/"source_report.json").write_text(json.dumps(report,indent=2)+"\n")
    return report

def main():
    p=argparse.ArgumentParser()
    p.add_argument("command",choices=["check","release","acquire"])
    p.add_argument("--out",type=Path,default=ROOT/".staging/tanzil-candidate")
    args=p.parse_args()
    try:
        if args.command=="check":
            check();print("PASS: 114 Surahs, 6236 counts, fail-closed Quran and brand policy")
        elif args.command=="release":
            release_check();print("PASS: release")
        else:
            print(json.dumps(acquire(args.out),indent=2))
        return 0
    except (IntegrityError,ValueError,KeyError,TypeError,OSError) as e:
        print("FAIL: "+str(e),file=sys.stderr);return 1
if __name__=="__main__":sys.exit(main())
