#
# Class to be used with asciidoctor to generate an HTML version of the documentation guides
# with the CSS file used by the Web admin.
#
# Usage example:
#
#   asciidoctor \
#           -D docs/html \
#           -n \
#           -r /usr/local/pf/docs/html/html.rb \
#           -a imagesdir=../images \
#           -a stylesdir=/usr/local/pf/html/pfappserver/root/static.alt/dist/css \
#           -a stylesheet=app.7e83572f.css \
#           docs/PacketFence_Installation_Guide.asciidoc
#
# This class extends the html5 converter:
# https://github.com/asciidoctor/asciidoctor/blob/master/lib/asciidoctor/converter/html5.rb
#
# TODO:
#   - add support for inline syntax highligher (-a source-highlighter=highlightjs)
#

class PfHtml5Converter < (Asciidoctor::Converter.for 'html5')
  register_for 'html5'

def convert_document node
  br = %(<br#{slash = @void_element_slash}>)
  unless (asset_uri_scheme = (node.attr 'asset-uri-scheme', 'https')).empty?
    asset_uri_scheme = %(#{asset_uri_scheme}:)
  end
  cdn_base_url = %(#{asset_uri_scheme}//cdnjs.cloudflare.com/ajax/libs)
  linkcss = node.attr? 'linkcss'
  result = ['<!DOCTYPE html>']
  lang_attribute = (node.attr? 'nolang') ? '' : %( lang="#{node.attr 'lang', 'en'}")
  result << %(<html#{@xml_mode ? ' xmlns="http://www.w3.org/1999/xhtml"' : ''}#{lang_attribute} class="h-100">)
  result << %(<head>
<meta charset="#{node.attr 'encoding', 'UTF-8'}"#{slash}>
<meta http-equiv="X-UA-Compatible" content="IE=edge"#{slash}>
<meta name="viewport" content="width=device-width, initial-scale=1.0"#{slash}>
<meta name="generator" content="Asciidoctor #{node.attr 'asciidoctor-version'}"#{slash}>)
  result << %(<meta name="application-name" content="#{node.attr 'app-name'}"#{slash}>) if node.attr? 'app-name'
  result << %(<meta name="description" content="#{node.attr 'description'}"#{slash}>) if node.attr? 'description'
  result << %(<meta name="keywords" content="#{node.attr 'keywords'}"#{slash}>) if node.attr? 'keywords'
  result << %(<meta name="author" content="#{((authors = node.sub_replacements node.attr 'authors').include? '<') ? (authors.gsub XmlSanitizeRx, '') : authors}"#{slash}>) if node.attr? 'authors'
  result << %(<meta name="copyright" content="#{node.attr 'copyright'}"#{slash}>) if node.attr? 'copyright'
  if node.attr? 'favicon'
    if (icon_href = node.attr 'favicon').empty?
      icon_href = 'favicon.ico'
      icon_type = 'image/x-icon'
    elsif (icon_ext = Helpers.extname icon_href, nil)
      icon_type = icon_ext == '.ico' ? 'image/x-icon' : %(image/#{icon_ext.slice 1, icon_ext.length})
    else
      icon_type = 'image/x-icon'
    end
    result << %(<link rel="icon" type="#{icon_type}" href="#{icon_href}"#{slash}>)
  end
  result << %(<title>#{node.doctitle sanitize: true, use_fallback: true}</title>)

  if Asciidoctor::DEFAULT_STYLESHEET_KEYS.include?(node.attr 'stylesheet')
    if (webfonts = node.attr 'webfonts')
      result << %(<link rel="stylesheet" href="#{asset_uri_scheme}//fonts.googleapis.com/css?family=#{webfonts.empty? ? 'Open+Sans:300,300italic,400,400italic,600,600italic%7CNoto+Serif:400,400italic,700,700italic%7CDroid+Sans+Mono:400,700' : webfonts}"#{slash}>)
    end
    if linkcss
      result << %(<link rel="stylesheet" href="#{node.normalize_web_path DEFAULT_STYLESHEET_NAME, (node.attr 'stylesdir', ''), false}"#{slash}>)
    else
      result << %(<style>
#{Asciidoctor::Stylesheets.instance.primary_stylesheet_data}
</style>)
    end
  elsif node.attr? 'stylesheet'
    if linkcss
      result << %(<link rel="stylesheet" href="#{node.normalize_web_path((node.attr 'stylesheet'), (node.attr 'stylesdir', ''))}"#{slash}>)
    else
      result << %(<style>
#{node.read_asset node.normalize_system_path((node.attr 'stylesheet'), (node.attr 'stylesdir', '')), warn_on_failure: true, label: 'stylesheet'}
</style>)
    end
  end

  if node.attr? 'icons', 'font'
    if node.attr? 'iconfont-remote'
      result << %(<link rel="stylesheet" href="#{node.attr 'iconfont-cdn', %[#{cdn_base_url}/font-awesome/#{FONT_AWESOME_VERSION}/css/font-awesome.min.css]}"#{slash}>)
    else
      iconfont_stylesheet = %(#{node.attr 'iconfont-name', 'font-awesome'}.css)
      result << %(<link rel="stylesheet" href="#{node.normalize_web_path iconfont_stylesheet, (node.attr 'stylesdir', ''), false}"#{slash}>)
    end
  end

  if (syntax_hl = node.syntax_highlighter) && (syntax_hl.docinfo? :head)
    result << (syntax_hl.docinfo :head, node, cdn_base_url: cdn_base_url, linkcss: linkcss, self_closing_tag_slash: slash)
  end

  unless (docinfo_content = node.docinfo).empty?
    result << docinfo_content
  end

  result << '</head>'
  body_attrs = node.id ? [%(id="#{node.id}")] : []
  if (sectioned = node.sections?) && (node.attr? 'toc-class') && (node.attr? 'toc') && (node.attr? 'toc-placement', 'auto')
    classes = [node.doctype, (node.attr 'toc-class'), %(toc-#{node.attr 'toc-position', 'header'})]
  else
    classes = [node.doctype]
  end
  classes << node.role if node.role?
  body_attrs << %(class="h-100 #{classes.join ' '}")
  body_attrs << %(style="max-width: #{node.attr 'max-width'};") if node.attr? 'max-width'
  result << %(<body #{body_attrs.join ' '}>)

  unless (docinfo_content = node.docinfo :header).empty?
    result << docinfo_content
  end

  result << '<div class="container-fluid h-100">'
  result << '  <div class="row h-100">'

  unless node.noheader
    result << '<div id="header" class="col-3 h-100 overflow-auto py-4">'

    if sectioned && (node.attr? 'toc') && (node.attr? 'toc-placement', 'auto')
      result << %(<div id="toc" class="#{node.attr 'toc-class', 'toc'}">
#{convert_outline node}
</div>)
    end
    result << '</div><!-- /#header -->'
  end

  result << %(<div id="guide" class="h-100 bg-white overflow-auto py-4 #{node.noheader ? 'col' : 'col-9'}"><div class="container">)

  if node.header?
    result << %(<h1 class="pb-6">#{node.header.title}</h1>) unless node.notitle
    details = []
    idx = 1
    node.authors.each do |author|
      details << %(<span id="author#{idx > 1 ? idx : ''}" class="author">#{node.sub_replacements author.name}</span>#{br})
      details << %(<span id="email#{idx > 1 ? idx : ''}" class="email">#{node.sub_macros author.email}</span>#{br}) if author.email
      idx += 1
    end
    if node.attr? 'revnumber'
      details << %(<span id="revnumber">#{((node.attr 'version-label') || '').downcase} #{node.attr 'revnumber'}#{(node.attr? 'revdate') ? ',' : ''}</span>)
    end
    if node.attr? 'revdate'
      details << %(<span id="revdate">#{node.attr 'revdate'}</span>)
    end
    if node.attr? 'revremark'
      details << %(#{br}<span id="revremark">#{node.attr 'revremark'}</span>)
    end
    unless details.empty?
      result << '<div class="details">'
      result.concat details
      result << '</div>'
    end
  end

  result << %(<div id="content">
  #{node.content}
</div>)

  if node.footnotes? && !(node.attr? 'nofootnotes')
    result << %(<div id="footnotes">
<hr#{slash}>)
    node.footnotes.each do |footnote|
      result << %(<div class="footnote" id="_footnotedef_#{footnote.index}">
<a href="#_footnoteref_#{footnote.index}">#{footnote.index}</a>. #{footnote.text}
</div>)
    end
    result << '</div>'
  end

  unless node.nofooter
    result << '<div id="footer" class="text-black-50">'
    result << '<div id="footer-text">'
    result << %(#{node.attr 'version-label'} #{node.attr 'revnumber'}#{br}) if node.attr? 'revnumber'
    result << %(#{node.attr 'last-update-label'} #{node.attr 'docdatetime'}) if (node.attr? 'last-update-label') && !(node.attr? 'reproducible')
    result << '</div>'
    result << '</div>'
  end

  result << '</div><!-- /#guide -->'
  result << '</div><!-- /.col -->'
  result << '</div><!-- /.row -->'
  result << '</div><!-- .container-fluid -->'

  # JavaScript (and auxiliary stylesheets) loaded at the end of body for performance reasons
  # See http://www.html5rocks.com/en/tutorials/speed/script-loading/

  if syntax_hl && (syntax_hl.docinfo? :footer)
    result << (syntax_hl.docinfo :footer, node, cdn_base_url: cdn_base_url, linkcss: linkcss, self_closing_tag_slash: slash)
  end

  if node.attr? 'stem'
    eqnums_val = node.attr 'eqnums', 'none'
    eqnums_val = 'AMS' if eqnums_val.empty?
    eqnums_opt = %( equationNumbers: { autoNumber: "#{eqnums_val}" } )
    # IMPORTANT inspect calls on delimiter arrays are intentional for JavaScript compat (emulates JSON.stringify)
    result << %(<script type="text/x-mathjax-config">
MathJax.Hub.Config({
messageStyle: "none",
tex2jax: {
  inlineMath: [#{INLINE_MATH_DELIMITERS[:latexmath].inspect}],
  displayMath: [#{BLOCK_MATH_DELIMITERS[:latexmath].inspect}],
  ignoreClass: "nostem|nolatexmath"
},
asciimath2jax: {
  delimiters: [#{BLOCK_MATH_DELIMITERS[:asciimath].inspect}],
  ignoreClass: "nostem|noasciimath"
},
TeX: {#{eqnums_opt}}
})
MathJax.Hub.Register.StartupHook("AsciiMath Jax Ready", function () {
MathJax.InputJax.AsciiMath.postfilterHooks.Add(function (data, node) {
  if ((node = data.script.parentNode) && (node = node.parentNode) && node.classList.contains('stemblock')) {
    data.math.root.display = "block"
  }
  return data
})
})
</script>
<script src="#{cdn_base_url}/mathjax/#{MATHJAX_VERSION}/MathJax.js?config=TeX-MML-AM_HTMLorMML"></script>)
  end

  unless (docinfo_content = node.docinfo :footer).empty?
    result << docinfo_content
  end

  result << '</body>'
  result << '</html>'
  result.join Asciidoctor::LF
end

def convert_outline node, opts = {}
return unless node.sections?
sectnumlevels = opts[:sectnumlevels] || (node.document.attributes['sectnumlevels'] || 3).to_i
toclevels = opts[:toclevels] || (node.document.attributes['toclevels'] || 2).to_i
sections = node.sections
# FIXME top level is incorrect if a multipart book starts with a special section defined at level 0
result = [%(<ul class="#{sections[0].level == 1 ? 'ml-3 list-unstyled ' : ''}sectlevel#{sections[0].level}">)]
sections.each do |section|
  slevel = section.level
  if section.caption
    stitle = section.captioned_title
  elsif section.numbered && slevel <= sectnumlevels
    if slevel < 2 && node.document.doctype == 'book'
      if section.sectname == 'chapter'
        stitle =  %(#{(signifier = node.document.attributes['chapter-signifier']) ? "#{signifier} " : ''}#{section.sectnum} #{section.title})
      elsif section.sectname == 'part'
        stitle =  %(#{(signifier = node.document.attributes['part-signifier']) ? "#{signifier} " : ''}#{section.sectnum nil, ':'} #{section.title})
      else
        stitle = %(#{section.sectnum} #{section.title})
      end
    else
      stitle = %(#{section.sectnum} #{section.title})
    end
  else
    stitle = section.title
  end
  stitle = stitle.gsub DropAnchorRx, '' if stitle.include? '<a'
  if slevel < toclevels && (child_toc_level = convert_outline section, toclevels: toclevels, sectnumlevels: sectnumlevels)
    result << %(<li#{sections[0].level == 1 ? ' class="mb-3" style="text-indent: -1rem"' : ''}><a href="##{section.id}">#{stitle}</a>)
    result << child_toc_level
    result << '</li>'
  else
    result << %(<li class="#{sections[0].level == 1 ? 'mb-3" style="text-indent: -1rem' : 'list-unstyled'}"><a href="##{section.id}">#{stitle}</a></li>)
  end
end
result << '</ul>'
result.join Asciidoctor::LF
end

def convert_section node
  doc_attrs = node.document.attributes
  level = node.level
  if node.caption
    title = node.captioned_title
  elsif node.numbered && level <= (doc_attrs['sectnumlevels'] || 3).to_i
    if level < 2 && node.document.doctype == 'book'
      if node.sectname == 'chapter'
        title = %(#{(signifier = doc_attrs['chapter-signifier']) ? "#{signifier} " : ''}#{node.sectnum} #{node.title})
      elsif node.sectname == 'part'
        title = %(#{(signifier = doc_attrs['part-signifier']) ? "#{signifier} " : ''}#{node.sectnum nil, ':'} #{node.title})
      else
        title = %(#{node.sectnum} #{node.title})
      end
    else
      title = %(#{node.sectnum} #{node.title})
    end
  else
    title = node.title
  end
  if node.id
    id_attr = %( id="#{id = node.id}")
    if doc_attrs['sectlinks']
      title = %(<a class="link" href="##{id}">#{title}</a>)
    end
    if doc_attrs['sectanchors']
      # QUESTION should we add a font-based icon in anchor if icons=font?
      if doc_attrs['sectanchors'] == 'after'
        title = %(#{title}<a class="anchor" href="##{id}"></a>)
      else
        title = %(<a class="anchor" href="##{id}"></a>#{title})
      end
    end
  else
    id_attr = ''
  end
  if level == 0
    %(<h1#{id_attr} class="sect0#{(role = node.role) ? " #{role}" : ''}">#{title}</h1>
#{node.content})
  else
    header_class = %(my-#{7 - level})
    sect_class = ''
    if level > 2
      header_class = %(mt-#{7 - level})
    elsif level == 1
      sect_class = 'pb-5 border-bottom'
    end
    %(<div class="#{sect_class} #{(role = node.role) ? " #{role}" : ''}">
<h#{level + 1}#{id_attr} class="#{header_class}">#{title}</h#{level + 1}>
#{level == 1 ? %[<div class="sectionbody">
#{node.content}
</div>] : node.content}
</div>)
  end
end

def convert_listing node
  nowrap = (node.option? 'nowrap') || !(node.document.attr? 'prewrap')
  if node.style == 'source'
    lang = node.attr 'language'
    if (syntax_hl = node.document.syntax_highlighter)
      opts = syntax_hl.highlight? ? {
        css_mode: ((doc_attrs = node.document.attributes)[%(#{syntax_hl.name}-css)] || :class).to_sym,
        style: doc_attrs[%(#{syntax_hl.name}-style)]
      } : {}
      opts[:nowrap] = nowrap
    else
      pre_open = %(<pre class="highlight#{nowrap ? ' nowrap' : ''} bg-secondary text-white rounded p-3"><code class="#{lang ? %[ language-#{lang}" data-lang="#{lang}] : ''}">)
      pre_close = '</code></pre>'
    end
  else
    pre_open = %(<pre class="bg-secondary text-white rounded p-3#{nowrap ? 'nowrap' : ''}"">)
    pre_close = '</pre>'
  end
  id_attribute = node.id ? %( id="#{node.id}") : ''
  title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : ''
  %(<div#{id_attribute} class="listingblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
#{syntax_hl ? (syntax_hl.format node, lang, opts) : pre_open + (node.content || '') + pre_close}
</div>
</div>)
end

def convert_literal node
  id_attribute = node.id ? %( id="#{node.id}") : ''
  title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
  nowrap = !(node.document.attr? 'prewrap') || (node.option? 'nowrap')
  %(<div#{id_attribute} class="literalblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
<pre class="bg-secondary text-white rounded p-3 #{nowrap ? 'nowrap' : ''}">#{node.content}</pre>
</div>
</div>)
end

def convert_dlist node
  result = []
  id_attribute = node.id ? %( id="#{node.id}") : ''

  classes = case node.style
  when 'qanda'
    ['qlist', 'qanda', node.role]
  when 'horizontal'
    ['hdlist', node.role]
  else
    ['dlist', node.style, node.role]
  end.compact

  class_attribute = %( class="#{classes.join ' '}")

  result << %(<div#{id_attribute}#{class_attribute}>)
  result << %(<div class="title">#{node.title}</div>) if node.title?
  case node.style
  when 'qanda'
    result << '<ol>'
    node.items.each do |terms, dd|
      result << '<li>'
      terms.each do |dt|
        result << %(<p><em>#{dt.text}</em></p>)
      end
      if dd
        result << %(<p>#{dd.text}</p>) if dd.text?
        result << dd.content if dd.blocks?
      end
      result << '</li>'
    end
    result << '</ol>'
  when 'horizontal'
    slash = @void_element_slash
    result << '<table>'
    if (node.attr? 'labelwidth') || (node.attr? 'itemwidth')
      result << '<colgroup>'
      col_style_attribute = (node.attr? 'labelwidth') ? %( style="width: #{(node.attr 'labelwidth').chomp '%'}%;") : ''
      result << %(<col#{col_style_attribute}#{slash}>)
      col_style_attribute = (node.attr? 'itemwidth') ? %( style="width: #{(node.attr 'itemwidth').chomp '%'}%;") : ''
      result << %(<col#{col_style_attribute}#{slash}>)
      result << '</colgroup>'
    end
    node.items.each do |terms, dd|
      result << '<tr>'
      result << %(<td class="hdlist1#{(node.option? 'strong') ? ' strong' : ''}">)
      first_term = true
      terms.each do |dt|
        result << %(<br#{slash}>) unless first_term
        result << dt.text
        first_term = nil
      end
      result << '</td>'
      result << '<td class="hdlist2">'
      if dd
        result << %(<p>#{dd.text}</p>) if dd.text?
        result << dd.content if dd.blocks?
      end
      result << '</td>'
      result << '</tr>'
    end
    result << '</table>'
  else
    result << '<dl>'
    dt_style_attribute = node.style ? '' : ' class="hdlist1"'
    node.items.each do |terms, dd|
      terms.each do |dt|
        result << %(<dt#{dt_style_attribute}>#{dt.text}</dt>)
      end
      if dd
        result << '<dd class="pl-4">'
        result << %(<p>#{dd.text}</p>) if dd.text?
        result << dd.content if dd.blocks?
        result << '</dd>'
      end
    end
    result << '</dl>'
  end

  result << '</div>'
  result.join Asciidoctor::LF
end

def convert_image node
  target = node.attr 'target'
  width_attr = (node.attr? 'width') ? %( width="#{node.attr 'width'}") : ''
  height_attr = (node.attr? 'height') ? %( height="#{node.attr 'height'}") : ''
  if ((node.attr? 'format', 'svg') || (target.include? '.svg')) && node.document.safe < SafeMode::SECURE &&
      ((svg = (node.option? 'inline')) || (obj = (node.option? 'interactive')))
    if svg
      img = (read_svg_contents node, target) || %(<span class="alt">#{node.alt}</span>)
    elsif obj
      fallback = (node.attr? 'fallback') ? %(<img src="#{node.image_uri(node.attr 'fallback')}" alt="#{encode_attribute_value node.alt}"#{width_attr}#{height_attr}#{@void_element_slash}>) : %(<span class="alt">#{node.alt}</span>)
      img = %(<object type="image/svg+xml" data="#{node.image_uri target}"#{width_attr}#{height_attr}>#{fallback}</object>)
    end
  end
  img ||= %(<img class="img-fluid" src="#{node.image_uri target}" alt="#{encode_attribute_value node.alt}"#{width_attr}#{height_attr}#{@void_element_slash}>)
  if node.attr? 'link'
    img = %(<a class="image" href="#{node.attr 'link'}"#{(append_link_constraint_attrs node).join}>#{img}</a>)
  end
  id_attr = node.id ? %( id="#{node.id}") : ''
  classes = ['pb-4']
  classes << (node.attr 'float') if node.attr? 'float'
  classes << %(text-#{node.attr 'align'}) if node.attr? 'align'
  classes << node.role if node.role
  class_attr = %( class="#{classes.join ' '}")
  title_el = node.title? ? %(\n<div class="title">#{node.captioned_title}</div>) : ''
  %(<div#{id_attr}#{class_attr}>
#{img}
#{title_el}
</div>)
end

def convert_admonition node
  id_attr = node.id ? %( id="#{node.id}") : ''
  name = node.attr 'name'
  title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
  if node.document.attr? 'icons'
    if (node.document.attr? 'icons', 'font') && !(node.attr? 'icon')
      label = %(<i class="fa icon-#{name}" title="#{node.attr 'textlabel'}"></i>)
    else
      label = %(<img src="#{node.icon_uri name}" alt="#{node.attr 'textlabel'}"#{@void_element_slash}>)
    end
  else
    label = %(<div class="title">#{node.attr 'textlabel'}</div>)
  end
  color = '17a2b8'
  if (name == 'caution')
    color = 'f77d05'
  end
  %(<div#{id_attr} class="alert bg-light" style="border-left: 3px solid ##{color}">
<div class="media pt-2 pb-2">
  <div class="mr-3 align-self-start">
    <svg preserveAspectRatio="xMidYMid meet" height="1.5em" width="1.5em" fill="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" stroke="none" style="color:##{color}"><g><path d="M12.2 8.98c.06-.01.12-.03.18-.06.06-.02.12-.05.18-.09l.15-.12c.18-.19.29-.45.29-.71 0-.06-.01-.13-.02-.19a.603.603 0 0 0-.06-.19.757.757 0 0 0-.09-.18c-.03-.05-.08-.1-.12-.15-.28-.27-.72-.37-1.09-.21-.13.05-.23.12-.33.21-.04.05-.09.1-.12.15-.04.06-.07.12-.09.18-.03.06-.05.12-.06.19-.01.06-.02.13-.02.19 0 .26.11.52.29.71.1.09.2.16.33.21.12.05.25.08.38.08.06 0 .13-.01.2-.02M13 16v-4a1 1 0 1 0-2 0v4a1 1 0 1 0 2 0M12 3c-4.962 0-9 4.038-9 9 0 4.963 4.038 9 9 9 4.963 0 9-4.037 9-9 0-4.962-4.037-9-9-9m0 20C5.935 23 1 18.065 1 12S5.935 1 12 1c6.066 0 11 4.935 11 11s-4.934 11-11 11" fill-rule="evenodd"></path></g></svg>
  </div>
  <div class="media-body">#{node.content}</div>
</div>
</div>)
end

def convert_table node
  result = []
  id_attribute = node.id ? %( id="#{node.id}") : ''
  classes = ['table', %(frame-#{node.attr 'frame', 'all', 'table-frame'}), %(grid-#{node.attr 'grid', 'all', 'table-grid'})]
  if (stripes = node.attr 'stripes', nil, 'table-stripes')
    classes << %(stripes-#{stripes})
  end
  styles = []
  if (autowidth = node.option? 'autowidth') && !(node.attr? 'width')
    classes << 'fit-content'
  elsif (tablewidth = node.attr 'tablepcwidth') == 100
    classes << 'stretch'
  else
    styles << %(width: #{tablewidth}%;)
  end
  classes << (node.attr 'float') if node.attr? 'float'
  if (role = node.role)
    classes << role
  end
  class_attribute = %( class="#{classes.join ' '}")
  style_attribute = styles.empty? ? '' : %( style="#{styles.join ' '}")

  result << '<div class="table-responsive">'
  result << %(<table#{id_attribute}#{class_attribute}#{style_attribute}>)
  result << %(<caption class="title">#{node.captioned_title}</caption>) if node.title?
  if (node.attr 'rowcount') > 0
    slash = @void_element_slash
    result << '<colgroup>'
    if autowidth
      result += (Array.new node.columns.size, %(<col#{slash}>))
    else
      node.columns.each do |col|
        result << ((col.option? 'autowidth') ? %(<col#{slash}>) : %(<col style="width: #{col.attr 'colpcwidth'}%;"#{slash}>))
      end
    end
    result << '</colgroup>'
    node.rows.to_h.each do |tsec, rows|
      next if rows.empty?
      result << %(<t#{tsec} class="t#{tsec}-light">)
      rows.each do |row|
        result << '<tr>'
        row.each do |cell|
          if tsec == :head
            cell_content = cell.text
          else
            case cell.style
            when :asciidoc
              cell_content = %(<div class="content">#{cell.content}</div>)
            when :literal
              cell_content = %(<div class="literal"><pre>#{cell.text}</pre></div>)
            else
              cell_content = (cell_content = cell.content).empty? ? '' : %(<div class="tableblock">#{cell_content.join '</div>
<div class="tableblock">'}</div>)
            end
          end

          cell_tag_name = (tsec == :head || cell.style == :header ? 'th' : 'td')
          cell_class_attribute = %( class="text-#{cell.attr 'halign'} align-#{cell.attr 'valign'}")
          cell_colspan_attribute = cell.colspan ? %( colspan="#{cell.colspan}") : ''
          cell_rowspan_attribute = cell.rowspan ? %( rowspan="#{cell.rowspan}") : ''
          cell_style_attribute = (node.document.attr? 'cellbgcolor') ? %( style="background-color: #{node.document.attr 'cellbgcolor'};") : ''
          result << %(<#{cell_tag_name}#{cell_class_attribute}#{cell_colspan_attribute}#{cell_rowspan_attribute}#{cell_style_attribute}>#{cell_content}</#{cell_tag_name}>)
        end
        result << '</tr>'
      end
      result << %(</t#{tsec}>)
    end
  end
  result << '</table>'
  result << '</div>'
  result.join Asciidoctor::LF
end

end
