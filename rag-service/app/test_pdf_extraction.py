from PyPDF2 import PdfReader
import os

def test_pdf_extraction(file_path):
    """Test PDF extraction to see what content is actually extracted"""
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return

    print(f"Testing extraction for: {file_path}")
    print("=" * 50)

    with open(file_path, 'rb') as file:
        reader = PdfReader(file)
        print(f"Number of pages: {len(reader.pages)}")

        for i, page in enumerate(reader.pages):
            print(f"\n--- Page {i+1} ---")
            text = page.extract_text()
            print(f"Text length: {len(text)} characters")
            print("Content preview:")
            print(text[:500] + "..." if len(text) > 500 else text)
            print("-" * 30)

if __name__ == "__main__":
    # Test with the uploaded file
    test_file = "./temp/Competencies Management.pdf"
    test_pdf_extraction(test_file)
