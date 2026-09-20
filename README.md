# LLM Systems Principles

A lightweight Quarto project that presents the same set of LLM-system engineering principles for two audiences:

- `principles/human-reference.qmd` — the user-facing reference document. This is copied unchanged from the supplied source file.
- `principles/llm-directives.qmd` — concise directives intended to be passed to ChatGPT, Codex, or another LLM when designing or reviewing an LLM-assisted system.

The website is generated programmatically from those two source documents. `R/render-principles.R` parses the principle headings and human-facing `Description`, `Requirements`, and `Example` sections, joins them by principle name/order to the LLM directives, and emits the comparison table used by `index.qmd`.

## Render

Open `llm-systems-principles.Rproj` and render the Quarto project, or run:

```bash
quarto render
```

The rendered site is written to `_site/`.

## Editing contract

Edit the two files under `principles/`. Do not manually duplicate their prose in `index.qmd` or the rendering script. The build intentionally fails if the principle names or ordering differ between the two source documents.
