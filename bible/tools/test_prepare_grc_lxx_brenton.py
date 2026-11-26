import io,sys,unittest,zipfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from prepare_grc_lxx_brenton import SOURCE_BOOKS,BOOK_ID,TRANSLATION_ID,parse_archive
class BrentonTests(unittest.TestCase):
 def test_all_52_source_books_are_preserved(self):
  self.assertEqual(len(SOURCE_BOOKS),52)
  self.assertEqual(BOOK_ID["ESG"],"est")
  self.assertEqual(BOOK_ID["DAG"],"dan")
  self.assertEqual(BOOK_ID["3MA"],"3ma")
  self.assertEqual(BOOK_ID["4MA"],"4ma")
 def test_parse_complete_synthetic_archive(self):
  data=io.BytesIO()
  with zipfile.ZipFile(data,"w") as z:
   for code in SOURCE_BOOKS:
    z.writestr(code+".SFM",f"\\id {code}\n\\c 1\n\\v 1 Ἐν ἀρχῇ ἐποίησεν ὁ Θεός\n\\v 2 καὶ ἡ γῆ\n")
  rows,cov=parse_archive(data.getvalue())
  self.assertEqual(TRANSLATION_ID,"GRC-LXX-BRENTON-1851")
  self.assertEqual(len(rows),104)
  self.assertEqual(len(cov),52)
  self.assertEqual(rows[0]["book_id"],"gen")
  self.assertIn("3ma",{r["book_id"] for r in rows})
if __name__=="__main__": unittest.main()
