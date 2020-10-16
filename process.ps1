<#
Based on https://github.com/plain-plain-text/simple-cv/blob/master/process.sh
This PowerShell script processes the files in this repository to generate
a few temporary files and a final pdf and html file for a CV.
If you cannot get this script to run on your local computer, as an initial, security-risky
solution, run this command in Powershell:
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
At the end of your CV-ing, you can set the policy back to the Windows default:
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser
Alternatively, you can run powershell itself with different execution policy.
To do that, open a command prompt and run:
powershell -ExecutionPolicy Unrestricted
For the duration of that shell, the policy will be unrestricted.
#>

# 1. Reset tmp directory
if(!(Test-Path -Path .\tmp)){
    New-Item -ItemType directory -Path .\tmp
} else {
    Get-ChildItem -Path .\tmp -Include *.* -File -Recurse | foreach { $_.Delete()}
}

# 2. collapse metadata/yml files into one and add a --- for the first line.
"---" | Out-File .\tmp\metadata.yml -Encoding utf8
$metadata = Get-Content .\metadata\*.yml -Encoding utf8
Add-Content .\tmp\metadata.yml $metadata

# 3. Set date.
$datestring = "date: " + (Get-Date -Format "yyyy-MM-dd")
Add-Content .\tmp\metadata.yml $datestring

<#
# 4. Set templates
This is a future feature that takes the `mode` key and sets
the CV to markdown or yaml depending.
#>

# 5. Set headings style
if(cat .\tmp\metadata.yml | Select-String -Pattern "^\s*headings: margin"){
    Add-Content .\tmp\metadata.yml "margin-heading: true"
}

# 6. Close metadata block.
Add-Content .\tmp\metadata.yml "---"

# 7. Concatenate sections into one large Markdown file.
if(Test-Path -Path sections.txt -PathType Leaf){
    " " | Out-File .\tmp\raw-md.md -Encoding utf8
    cat .\sections.txt |
    Select-String -Pattern "^[^#]" |
    foreach {
        $md_file = cat "sections\$($_).md" -Encoding utf8
        Add-Content .\tmp\raw-md.md $md_file
        Add-Content .\tmp\raw-md.md " "
    }
} else {
    "Could not find file 'sections.txt'"
    exit
}

# 8. Grab filename.
if(cat .\tmp\metadata.yml | Select-String -Pattern "^\s*filename:"){
    $pdf_filename = (Get-Content .\tmp\metadata.yml |
        Select-String -Pattern "^\s*filename:" |
        Out-String).Split(" ")[1]
} else {
    $pdf_filename = "CV"
}

# 9. Invoke pandoc
"Generating .tex, .pdf, and .html files."
$pandoc_tex_args = @(
    "--standalone",
    "--template=templates\tex-windows.tex",
    "--metadata-file=tmp\metadata.yml",
    "--from=markdown+yaml_metadata_block+raw_tex",
    "--output=tmp\out.tex",
    ".\tmp\raw-md.md"
)
$pandoc_html_args = @(
    "--standalone",
    "--template=templates\html-new.html",
    "--metadata-file=tmp\metadata.yml",
    "--from=markdown+yaml_metadata_block+raw_tex",
    "--output=docs\index.html",
    "--output=..\nicktackes\layouts\partials\CV.html",
    ".\tmp\raw-md.md"
)
$pandoc_pdf_args = @(
    "--standalone",
    "--template=templates\tex-windows.tex",
    "--pdf-engine=xelatex",
    "--metadata-file=tmp\metadata.yml",
    "--from=markdown+yaml_metadata_block+raw_tex",
    "--output=..\nicktackes\static\documents\latex.pdf",
    ".\tmp\raw-md.md"
)
$pandoc_docx_args = @(
    "--standalone",
    "--pdf-engine=xelatex",
    "--metadata-file=tmp\metadata.yml",
    "--from=markdown+yaml_metadata_block+raw_tex",
    "--reference-doc=/Users/jtack/AppData/Roaming/pandoc/cv-reference.docx",
    "--output=..\nicktackes\static\documents\$($pdf_filename).docx",
    ".\tmp\raw-md.md"
)
pandoc $pandoc_tex_args
".tex saved as .\tmp\out.tex"
pandoc $pandoc_html_args
".html saved as .\docs\index.html"
pandoc $pandoc_pdf_args
".pdf saved as ..\nicktackes\static\documents\latex.pdf"
pandoc $pandoc_docx_args
".docx saved as ..\nicktackes\static\documents\$($pdf_filename).docx"

$documents_path = '..\nicktackes\static\documents\'

$word_app = New-Object -ComObject Word.Application
"writing .docx to .pdf"

# This filter will find .doc as well as .docx documents
Get-ChildItem -Path $documents_path -Filter *.doc? | ForEach-Object {

    $document = $word_app.Documents.Open($_.FullName)

    $pdf_filename = "$($_.DirectoryName)\$($_.BaseName).pdf"

    $document.SaveAs([ref] $pdf_filename, [ref] 17)

    $document.Close()

}

$word_app.Quit()
"done!"
