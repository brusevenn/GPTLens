import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"src"))
from run_auditor import prompt_wrap
from prompts import auditor_prompt,auditor_format_constrain
class StablePrefixTests(unittest.TestCase):
 def test_native_instruction_words_unchanged_and_code_heading_last(self):
  x=prompt_wrap(auditor_prompt,auditor_format_constrain,"SOURCE_A",3,"prefix_stable_v2")
  y=prompt_wrap(auditor_prompt,auditor_format_constrain,"SOURCE_B",3,"prefix_stable_v2")
  self.assertEqual(x[:-8],y[:-8])
  self.assertTrue(x.endswith("Smart contract code:\n\nSOURCE_A"))
  self.assertIn(auditor_format_constrain,x)
if __name__=="__main__":unittest.main()
