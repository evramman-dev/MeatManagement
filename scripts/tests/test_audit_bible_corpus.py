import pathlib,sys,unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
import audit_bible_corpus as a

class AuditTests(unittest.TestCase):
    def test_missing_and_extra_book_ids(self):
        r=a.audit_edition([{"book_id":"gen","chapter":1,"verse_label":"1","text":"x"},{"book_id":"extra","chapter":1,"verse_label":"1","text":"y"}],{"gen","exo"})
        self.assertEqual(r["missing_expected_books"],["exo"])
        self.assertEqual(r["extra_books"],["extra"])
    def test_duplicate_references_are_reported_not_removed(self):
        rows=[{"book_id":"dan","chapter":1,"verse_label":"1","text":"a"},{"book_id":"dan","chapter":1,"verse_label":"1","text":"b"}]
        r=a.audit_edition(rows,{"dan"})
        self.assertEqual(r["record_count"],2)
        self.assertEqual(r["duplicate_reference_groups"],1)
        self.assertEqual(r["duplicate_extra_records"],1)
    def test_chapter_gaps_and_empty_text(self):
        rows=[{"book_id":"gen","chapter":1,"verse_label":"1","text":"a"},{"book_id":"gen","chapter":3,"verse_label":"1","text":""}]
        r=a.audit_edition(rows,{"gen"})
        self.assertEqual(r["books"]["gen"]["missing_internal_chapter_numbers"],[2])
        self.assertEqual(r["empty_text_records"],1)
    def test_chapter_pair_comparison(self):
        left=[{"book_id":"gen","chapter":1},{"book_id":"gen","chapter":1}]
        right=[{"book_id":"gen","chapter":1}]
        r=a.compare("a","b",left,right)
        self.assertEqual(r["different_book_chapter_pairs"],1)
        self.assertEqual(r["record_count_difference"],1)
    def test_hebrew_wlc_scope(self):
        ot="gen exo lev num deu jos jdg rut 1sa 2sa 1ki 2ki 1ch 2ch ezr neh tob jdt est job psa pro ecc sng wis sir isa jer lam bar ezk dan hos jol amo oba jon mic nam hab zep hag zec mal 1ma 2ma".split()
        catalog={"books":[{"book_id":b,"testament":"OT"} for b in ot]+[{"book_id":"mat","testament":"NT"}]}
        manifest={"edition_metadata":{"wlc_hebrew_ot":{"testament":"OT"}}}
        rows={"wlc_hebrew_ot":[{"book_id":b,"chapter":1,"verse_label":"1","text":"x"} for b in (set(ot)-{"tob","jdt","wis","sir","bar","1ma","2ma"})]}
        e=a.build_audit(catalog,manifest,rows)["editions"]["wlc_hebrew_ot"]
        self.assertEqual(e["missing_expected_books"],[])
        self.assertEqual(set(e["coptic_canon_books_outside_source_scope"]),{"tob","jdt","wis","sir","bar","1ma","2ma"})

if __name__=="__main__": unittest.main()
