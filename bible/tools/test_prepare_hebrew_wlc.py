import sys, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from prepare_hebrew_wlc import OT_BOOKS, TRANSLATION_ID, parse_archive
import io, zipfile

class HebrewWlcTests(unittest.TestCase):
    def test_book_mapping_is_39_masoretic_books(self):
        self.assertEqual(len(OT_BOOKS),39)
        self.assertEqual(OT_BOOKS["GEN"],"gen")
        self.assertEqual(OT_BOOKS["PSA"],"psa")
        self.assertNotIn("TOB",OT_BOOKS)
    def test_parse_minimal_hebrew_usfm(self):
        data=io.BytesIO()
        with zipfile.ZipFile(data,"w") as z:
            z.writestr("GEN.SFM","\\id GEN\n\\c 1\n\\v 1 בְּרֵאשִׁית בָּרָא אֱלֹהִים\n\\v 2 וְהָאָרֶץ\n")
        rows,coverage=parse_archive(data.getvalue())
        self.assertEqual(TRANSLATION_ID,"HE-WLC-2017")
        self.assertEqual(len(rows),2)
        self.assertEqual(rows[0]["book_id"],"gen")
        self.assertEqual(rows[0]["chapter"],1)
        self.assertEqual(rows[0]["verse"],"1")
        self.assertIn("בְּרֵאשִׁית",rows[0]["text"])
if __name__=="__main__": unittest.main()
