"""The PDF/A check reads veraPDF's XML report: compliant files pass, failed
rules and unparsed files are problems."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_pdfa  # noqa: E402

REPORT = """<report><jobs>
<job><item size="1"><name>C:\\t\\good.pdf</name></item><validationReport isCompliant="true"></validationReport></job>
<job><item size="1"><name>C:\\t\\bad.pdf</name></item><validationReport isCompliant="false">
<rule specification="ISO 19005-2:2011" clause="6.2.11.4.1" testNumber="1" status="failed" failedChecks="2"></rule>
<rule specification="ISO 19005-2:2011" clause="6.1.3" testNumber="1" status="passed"></rule>
</validationReport></job>
<job><item size="1"><name>C:\\t\\broken.pdf</name></item><taskException/></job>
</jobs></report>"""


def test_failures() -> None:
    assert check_pdfa.failures(REPORT) == [
        "bad.pdf: PDF/A-2b clause 6.2.11.4.1 test 1",
        "broken.pdf: not checked",
    ]
