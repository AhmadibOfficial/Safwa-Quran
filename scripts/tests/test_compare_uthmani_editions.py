import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from compare_uthmani_editions import git_sha,parse_primary,parse_secondary,compare,IntegrityError
class Tests(unittest.TestCase):
    def test_blob_sha(self):
        self.assertEqual(git_sha(b"hello\n"),"ce013625030ba8dba906f756967f9e9ca394464a")
    def test_parser(self):
        self.assertEqual(parse_primary("1|1|بِسْمِ\n1|2|ٱلْحَمْدُ\n# note".encode()),
                         {(1,1):"بِسْمِ",(1,2):"ٱلْحَمْدُ"})
    def test_duplicate_fails(self):
        with self.assertRaises(IntegrityError):parse_primary(b"1|1|abc\n1|1|def\n")
    def test_short_secondary_fails(self):
        with self.assertRaises(IntegrityError):parse_secondary(b"a\n",[(1,1),(1,2)])
    def test_comparison_never_approves_or_edits(self):
        a={(1,n):"سلام" for n in range(1,6237)}
        b=dict(a);b[(1,2)]="سـلام";b[(1,3)]="غير"
        result=compare(a,b)
        self.assertEqual((result["exact"],result["tatweel_only_diagnostic"],result["remaining_count"]),(6234,1,1))
        self.assertEqual(result["remaining_references"],["1:3"])
        self.assertFalse(result["release_allowed"])
        self.assertEqual(a[(1,2)],"سلام")
if __name__=="__main__":unittest.main()
