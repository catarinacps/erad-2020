(TeX-add-style-hook
 "ERAD"
 (lambda ()
   (TeX-add-to-alist 'LaTeX-provided-class-options
                     '(("article" "12pt")))
   (TeX-add-to-alist 'LaTeX-provided-package-options
                     '(("inputenc" "utf8") ("fontenc" "T1") ("ulem" "normalem") ("minted" "cache=false" "outputdir=org-exports") ("inputenx" "utf8") ("babel" "brazil" "brazilian") ("subfig" "caption=false")))
   (add-to-list 'LaTeX-verbatim-environments-local "minted")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "path")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "url")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "nolinkurl")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "hyperbaseurl")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "hyperimage")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "hyperref")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "href")
   (add-to-list 'LaTeX-verbatim-macros-with-delims-local "path")
   (TeX-run-style-hooks
    "latex2e"
    "article"
    "art12"
    "inputenc"
    "fontenc"
    "graphicx"
    "grffile"
    "longtable"
    "wrapfig"
    "rotating"
    "ulem"
    "amsmath"
    "textcomp"
    "amssymb"
    "capt-of"
    "hyperref"
    "minted"
    "inputenx"
    "placeins"
    "sbc-template"
    "babel"
    "subfig"
    "booktabs"
    "hyphenat")
   (LaTeX-add-labels
    "sec:org5909530"
    "sec:org48b5dae"
    "sec:orgc7ce29c"
    "sec:org1cafe92"
    "sec:orga1829da"
    "sec:org130c3a6"
    "sec:org4f30eed"
    "sec:orgc74de53"
    "sec:orgb8632bb"
    "sec:org4cd723b"))
 :latex)

