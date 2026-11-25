import pathlib, tempfile, unittest, sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
import convert_bible_sources as c

class ConverterTests(unittest.TestCase):
    def test_verse_label_ranges_and_suffixes(self):
        self.assertEqual(c.parse_verse_label('3a-4b'),(3,'a',4,'b'))
        self.assertEqual(c.parse_verse_label('12'),(12,None,None,None))
    def test_usfm_word_attributes_are_removed_from_display_text(self):
        raw='\\w בְּרֵאשִׁ֖ית|strong="H7225" x-morph="HR"\\w* \\w בָּרָא|strong="H1254"\\w*'
        self.assertEqual(c.clean_usfm_inline(raw),'בְּרֵאשִׁ֖ית בָּרָא')
    def test_usfm_chapters_and_verse_labels(self):
        raw='\\id GEN\n\\c 1\n\\p\n\\v 1 In the beginning.\n\\v 2a Second part.\n\\c 2\n\\v 1 New chapter.'
        rows=c.usfm_records(raw.encode(),'test','fixture','fixture.usfm')
        self.assertEqual([(r['book_id'],r['chapter'],r['verse_label']) for r in rows],[('gen',1,'1'),('gen',1,'2a'),('gen',2,'1')])
        self.assertNotIn('_parts',rows[0])
        self.assertNotIn('_raw',rows[0])
    def test_csv_uses_label_not_malformed_chapter_columns(self):
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'sample.csv'; p.write_text('book,chapter,verse,label,body\ngenesis,{,1,1:1,Text\n',encoding='utf8')
            rows=c.csv_records(p,'edition','source')
        self.assertEqual((rows[0]['book_id'],rows[0]['chapter'],rows[0]['verse_label']),('gen',1,'1'))
    def test_lxx_duplicates_are_preserved_as_distinct_variants(self):
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'sample.csv'; p.write_text('book,chapter,verse,label,body\ndaniel,{,1,1:1,First\ndaniel,{,1,1:1,Second\n',encoding='utf8')
            rows=c.csv_records(p,'lxx','source',True)
        self.assertEqual([r['variant_index'] for r in rows],[1,2])
        self.assertEqual([r['variant_count'] for r in rows],[2,2])
        self.assertEqual([r['text'] for r in rows],['First','Second'])

if __name__=='__main__': unittest.main()
