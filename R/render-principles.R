html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

inline_markdown <- function(x) {
  x <- html_escape(x)
  x <- gsub("`([^`]+)`", "<code>\\1</code>", x, perl = TRUE)
  x <- gsub("\\*\\*([^*]+)\\*\\*", "<strong>\\1</strong>", x, perl = TRUE)
  x <- gsub("\\*([^*]+)\\*", "<em>\\1</em>", x, perl = TRUE)
  x
}

strip_yaml <- function(lines) {
  if (length(lines) >= 2 && trimws(lines[1]) == "---") {
    end <- which(trimws(lines[-1]) == "---")[1] + 1
    if (!is.na(end)) return(lines[-seq_len(end)])
  }
  lines
}

parse_fenced_block <- function(lines, i) {
  fence <- trimws(lines[i])
  end <- i + which(trimws(lines[(i + 1):length(lines)]) == "```")[1]
  if (is.na(end)) stop("Unclosed fenced code block.")
  body <- lines[(i + 1):(end - 1)]
  body <- body[!(trimws(body) == "---")]
  while (length(body) && !nzchar(trimws(body[1]))) body <- body[-1]
  while (length(body) && !nzchar(trimws(body[length(body)]))) body <- body[-length(body)]
  list(html = paste0("<pre><code>", html_escape(paste(body, collapse = "\n")), "</code></pre>"), next_i = end + 1)
}

markdown_fragment <- function(lines) {
  if (!length(lines)) return("")
  out <- character()
  paragraph <- character()
  flush_paragraph <- function() {
    if (!length(paragraph)) return(NULL)
    txt <- paste(trimws(paragraph), collapse = " ")
    out <<- c(out, paste0("<p>", inline_markdown(txt), "</p>"))
    paragraph <<- character()
  }
  i <- 1
  while (i <= length(lines)) {
    line <- lines[i]
    if (grepl("^```", trimws(line))) {
      flush_paragraph()
      block <- parse_fenced_block(lines, i)
      out <- c(out, block$html)
      i <- block$next_i
      next
    }
    if (!nzchar(trimws(line))) {
      flush_paragraph()
      i <- i + 1
      next
    }
    paragraph <- c(paragraph, line)
    i <- i + 1
  }
  flush_paragraph()
  paste(out, collapse = "\n")
}

parse_human <- function(path) {
  lines <- strip_yaml(readLines(path, warn = FALSE, encoding = "UTF-8"))
  h1 <- grep("^# [^#]", lines)
  if (!length(h1)) stop("No principles found in human reference.")
  result <- vector("list", length(h1))
  for (j in seq_along(h1)) {
    start <- h1[j]
    end <- if (j < length(h1)) h1[j + 1] - 1 else length(lines)
    block <- lines[start:end]
    title <- sub("^#\\s+", "", block[1])
    h2 <- grep("^##\\s+", block)
    sections <- list()
    for (k in seq_along(h2)) {
      s <- h2[k]
      e <- if (k < length(h2)) h2[k + 1] - 1 else length(block)
      name <- sub("^##\\s+", "", block[s])
      sections[[name]] <- block[(s + 1):e]
    }
    result[[j]] <- list(
      title = title,
      description = markdown_fragment(sections[["Description"]]),
      requirements = markdown_fragment(sections[["Requirements"]]),
      example = markdown_fragment(sections[["Example"]])
    )
  }
  result
}

parse_llm <- function(path) {
  lines <- strip_yaml(readLines(path, warn = FALSE, encoding = "UTF-8"))
  h1 <- grep("^# [^#]", lines)
  if (!length(h1)) stop("No principles found in LLM directives.")
  result <- vector("list", length(h1))
  for (j in seq_along(h1)) {
    start <- h1[j]
    end <- if (j < length(h1)) h1[j + 1] - 1 else length(lines)
    title <- sub("^#\\s+", "", lines[start])
    body <- lines[(start + 1):end]
    result[[j]] <- list(title = title, directive = markdown_fragment(body))
  }
  result
}

slugify <- function(x) {
  x <- tolower(iconv(x, to = "ASCII//TRANSLIT"))
  x <- gsub("[^a-z0-9]+", "-", x)
  gsub("(^-|-$)", "", x)
}

render_principles_table <- function(human_path, llm_path) {
  human <- parse_human(human_path)
  llm <- parse_llm(llm_path)
  human_names <- vapply(human, `[[`, character(1), "title")
  llm_names <- vapply(llm, `[[`, character(1), "title")
  if (!identical(human_names, llm_names)) {
    stop("Human and LLM principle names/order do not match. Keep the two source documents synchronized.")
  }

  cat('<div class="principles-toolbar" aria-label="Table display controls">')
  cat('<div class="view-toggle" role="group" aria-label="Visible columns">')
  cat('<button type="button" class="view-button is-active" data-view="both">Both</button>')
  cat('<button type="button" class="view-button" data-view="human">Human</button>')
  cat('<button type="button" class="view-button" data-view="llm">LLM</button>')
  cat('</div>')
  cat('<button type="button" class="prompt-builder-toggle" id="prompt-builder-toggle" aria-expanded="false" aria-controls="prompt-builder">Build prompt</button>')
  cat('</div>')

  cat('<div class="principles-layout">')
  cat('<div class="principles-table" id="principles-table">')
  cat('<div class="principles-head" role="row">')
  cat('<div class="head-principle">Principle</div>')
  cat('<div class="head-human">Human reference</div>')
  cat('<div class="head-llm">LLM directive</div>')
  cat('</div>')

  for (i in seq_along(human)) {
    h <- human[[i]]
    d <- llm[[i]]
    id <- slugify(h$title)
    directive_text <- gsub("<[^>]+>", " ", d$directive)
    directive_text <- gsub("\\s+", " ", directive_text)
    cat(sprintf('<section class="principle-row" id="%s">', id))
    cat('<div class="principle-label">')
    cat(sprintf('<span class="principle-number">%02d</span>', i))
    cat(sprintf('<h2>%s</h2>', html_escape(h$title)))
    cat(sprintf('<button class="select-principle" type="button" data-principle="%s" aria-pressed="false">Add</button>', id))
    cat('</div>')
    cat('<div class="human-cell">')
    cat('<div class="section-label">Description</div>', h$description)
    cat('<div class="section-label">Requirements</div>', h$requirements)
    cat('<div class="section-label">Example</div>', h$example)
    cat('</div>')
    cat('<div class="llm-cell">')
    cat('<div class="directive-topline"><span class="section-label">Directive</span>')
    cat(sprintf('<button class="copy-one" type="button" data-copy="%s" aria-label="Copy %s directive">Copy</button></div>',
                html_escape(directive_text), html_escape(h$title)))
    cat(d$directive)
    cat('</div>')
    cat('</section>')
  }
  cat('</div>')

  cat('<aside class="prompt-builder" id="prompt-builder" aria-label="LLM directive selection">')
  cat('<div class="prompt-builder-heading">')
  cat('<div><div class="prompt-builder-eyebrow">Build your prompt</div><h2>Select principles</h2></div>')
  cat('<div class="selection-count" id="selection-count" aria-live="polite"></div>')
  cat('</div>')
  cat('<div class="prompt-builder-actions">')
  cat('<button type="button" id="select-all">Select all</button>')
  cat('<button type="button" id="clear-selection">Clear</button>')
  cat('</div>')
  cat('<div class="principle-checklist">')
  for (i in seq_along(human)) {
    id <- slugify(human[[i]]$title)
    cat(sprintf('<div class="principle-choice" data-principle="%s"><input class="principle-select" type="checkbox" value="%s" aria-label="Include %s"><span class="choice-number">%02d</span><a class="principle-jump" href="#%s">%s</a></div>',
                id, id, html_escape(human[[i]]$title), i, id, html_escape(human[[i]]$title)))
  }
  cat('</div>')
  cat('<button type="button" class="copy-selected" id="copy-selected" disabled>Copy selected directives</button>')
  cat('</aside>')
  cat('</div>')
}
