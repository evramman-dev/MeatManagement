import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_ebible_usfm import parse_usfm


class UsfmParserTests(unittest.TestCase):
    def test_keeps_verse_text_and_removes_footnotes(self):
        sample = r"""\id JHN
\c 1
\p
\v 1 In the beginning \w Word|lemma="logos" strong="G3056"\w* was the Word.\f + \ft footnote\f*
\v 2 The same was in the beginning.
\c 2
\v 1 The next chapter starts here."""
        book, rows = parse_usfm(sample, "AR-SVD-1865", "Test")
        self.assertEqual(book, "JHN")
        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[0]["chapter"], 1)
        self.assertEqual(rows[0]["verse"], "1")
        self.assertIn("Word", rows[0]["text"])
        self.assertNotIn("logos", rows[0]["text"])
        self.assertNotIn("footnote", rows[0]["text"])
        self.assertEqual(rows[2]["chapter"], 2)

    def test_translation_layers_stay_separate(self):
        sample = r"""\id GEN
\c 1
\v 1 Text."""
        _, svd = parse_usfm(sample, "AR-SVD-1865", "Van Dyck")
        _, keh = parse_usfm(sample, "AR-KEH-2012", "Book of Life")
        self.assertEqual(svd[0]["translation_id"], "AR-SVD-1865")
        self.assertEqual(keh[0]["translation_id"], "AR-KEH-2012")
        self.assertNotEqual(svd[0]["edition"], keh[0]["edition"])


if __name__ == "__main__":
    unittest.main()
