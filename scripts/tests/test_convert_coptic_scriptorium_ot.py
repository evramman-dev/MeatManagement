import pathlib,sys,tempfile,unittest,zipfile
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
import convert_coptic_scriptorium_ot as c

class CopticOtParserTests(unittest.TestCase):
    def make_zip(self,xml):
        tmp=tempfile.TemporaryDirectory()
        path=pathlib.Path(tmp.name)/"sample.zip"
        with zipfile.ZipFile(path,"w") as z: z.writestr("01_Genesis_01.tt",xml)
        self.addCleanup(tmp.cleanup)
        return path
    def test_sahidic_keeps_normalized_and_original_text(self):
        xml='''<meta corpus="sahidic.ot" chapter="1" document_cts_urn="urn:cts:copticLit:ot.gen.coptot:1"><verse_n vname="Genesis 1:1" verse_n="1"><norm orig="ϩⲛ">ϩⲛ</norm><norm orig="ⲧⲁⲣⲭⲏ">ⲧⲁⲣⲭⲏ</norm></verse_n></meta>'''
        rows,docs,issues=c.parse_archive(self.make_zip(xml),"coptic_sahidic_ot_scriptorium_research")
        self.assertEqual(rows[0]["book_id"],"gen")
        self.assertEqual(rows[0]["display_candidate_text"],"ϩⲛ ⲧⲁⲣⲭⲏ")
        self.assertEqual(rows[0]["original_text"],"ϩⲛ ⲧⲁⲣⲭⲏ")
        self.assertEqual(issues,[])
    def test_bohairic_keeps_original_and_alignment(self):
        xml='''<meta corpus="bohairic.ot" chapter="01" document_cts_urn="urn:cts:copticLit:ot.gen.bohairic_ed:01"><verse_n verse_n="1"><translation translation="In the beginning."/><orig orig="ϧⲉⲛ"><norm>ϧⲉⲛ</norm></orig></verse_n></meta>'''
        rows,docs,issues=c.parse_archive(self.make_zip(xml),"coptic_bohairic_ot_scriptorium_research")
        self.assertEqual(rows[0]["original_text"],"ϧⲉⲛ")
        self.assertEqual(rows[0]["english_alignment_candidate"],"In the beginning.")
    def test_daniel_addition_stays_separate(self):
        xml='''<meta corpus="sahidic.ot" chapter="1" document_cts_urn="urn:cts:copticLit:ot.bel.coptot:1"><verse_n vname="Bel 1:1"><norm orig="ⲃⲉⲗ">ⲃⲉⲗ</norm></verse_n></meta>'''
        rows,docs,issues=c.parse_archive(self.make_zip(xml),"coptic_sahidic_ot_scriptorium_research")
        self.assertEqual(rows[0]["book_id"],"dan")
        self.assertEqual(rows[0]["textual_unit_id"],"dan_bel_dragon")
    def test_nonchapter_subscriptio_is_preserved(self):
        xml='''<meta corpus="sahidic.ot" chapter="Subscriptio" document_cts_urn="urn:cts:copticLit:ot.isa.coptot:Subscriptio"><verse_n vname="Isaiah Subscriptio:1"><norm orig="ⲏⲥⲁⲓⲁⲥ">ⲏⲥⲁⲓⲁⲥ</norm></verse_n></meta>'''
        rows,docs,issues=c.parse_archive(self.make_zip(xml),"coptic_sahidic_ot_scriptorium_research")
        self.assertIsNone(rows[0]["chapter"])
        self.assertEqual(rows[0]["source_chapter_label"],"Subscriptio")
    def test_recovery_marker_counts_are_compared(self):
        xml='''<meta corpus="sahidic.ot" chapter="1" document_cts_urn="urn:cts:copticLit:ot.gen.coptot:1"><verse_n vname="Genesis 1:1"><norm orig="x">x</norm></verse_n></meta>'''
        rows,docs,issues=c.parse_archive(self.make_zip(xml),"coptic_sahidic_ot_research")
        self.assertEqual(docs[0]["verse_markers_raw"],docs[0]["verse_markers_parsed"])
        self.assertEqual(docs[0]["norm_markers_raw"],docs[0]["norm_markers_parsed"])
        self.assertEqual(issues,[])

if __name__=="__main__": unittest.main()
