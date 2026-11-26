import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_grc_koine_rp2018 import BOOK_FILES, SOURCE_BOOK_IDS, TRANSLATION_ID, parse_csv_text
from qa_grc_koine_rp2018 import lexical_tokens

class RobinsonPierpontUnicodeTests(unittest.TestCase):
    def test_exactly_27_canonical_books_and_separate_alternatives(self):
        self.assertEqual(len(BOOK_FILES), 27)
        self.assertEqual(len(set(SOURCE_BOOK_IDS)), 27)
        self.assertEqual(TRANSLATION_ID, "GRC-KOINE-RP-2018")
        self.assertNotIn("PA", SOURCE_BOOK_IDS)
        self.assertNotIn("ACT24", SOURCE_BOOK_IDS)

    def test_csv_parser_preserves_polytonic_text_and_paragraph_marker(self):
        sample = 'chapter,verse,text\n1,1,"Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος. ¶Ἀμήν."\n'
        rows, chapters = parse_csv_text("JHN", "jhn", sample)
        self.assertEqual(chapters, {1})
        self.assertEqual(rows[0]["text"], "Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος. ¶Ἀμήν.")
        self.assertEqual(rows[0]["book_id"], "jhn")

    def test_comparison_normalization_does_not_change_saved_text(self):
        accented = "Ἐν ἀρχῇ ἦν ὁ λόγος."
        unaccented = "εν αρχη ην ο λογοσ"
        self.assertEqual(lexical_tokens(accented), lexical_tokens(unaccented))
        self.assertNotEqual(accented, unaccented)
        legacy = "πᾶς ὁ ἀγαπῶν 25 V-PAI-3S καὶ τὸν"
        clean = "πᾶς ὁ ἀγαπῶν καὶ τὸν"
        self.assertEqual(lexical_tokens(legacy), lexical_tokens(clean))

if __name__ == "__main__":
    unittest.main()
