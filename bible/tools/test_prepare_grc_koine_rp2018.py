import io,sys,unittest,zipfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from prepare_grc_koine_rp2018 import SOURCE_BOOKS,BOOK_ID,TRANSLATION_ID,parse_archive
class RobinsonPierpontTests(unittest.TestCase):
 def test_all_27_new_testament_books_are_expected(self):
  self.assertEqual(len(SOURCE_BOOKS),27)
  self.assertEqual(len(set(SOURCE_BOOKS)),27)
  self.assertEqual(BOOK_ID["MAT"],"mat")
  self.assertEqual(BOOK_ID["REV"],"rev")
 def test_parse_complete_synthetic_archive(self):
  data=io.BytesIO()
  with zipfile.ZipFile(data,"w") as z:
   for code in SOURCE_BOOKS:
    z.writestr(code+".SFM",f"\\id {code}\n\\c 1\n\\v 1 Ἐν ἀρχῇ ἦν ὁ λόγος\n\\v 2 καὶ ὁ λόγος\n")
  rows,cov=parse_archive(data.getvalue())
  self.assertEqual(TRANSLATION_ID,"GRC-KOINE-RP-2018")
  self.assertEqual(len(rows),54)
  self.assertEqual(len(cov),27)
  self.assertEqual(rows[0]["book_id"],"mat")
  self.assertIn("rev",{r["book_id"] for r in rows})
if __name__=="__main__": unittest.main()
