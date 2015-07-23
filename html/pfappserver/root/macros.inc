[%- MACRO l(text, args) BLOCK;c.localize(text, args) | none ;END -%]

[%- MACRO i18n(text, args) BLOCK;c.localize(text, args) | none ;END -%]

[%- MACRO i18n_format(text, args) BLOCK;c.localize(text, args) | none;END -%]

[%- MACRO pagination_path(section, params)  BLOCK -%]
    [%- tags =  [ 'page_num'  'by'  'direction'  'per_page'  'filter'] -%]
    [%- "${section}" -%]
    [%- FOREACH key IN params.keys  -%]
        [%- IF params.$key -%]
            [%- path_part = params.$key | uri -%]
            [%- "/${key}/${path_part}" -%]
        [%- END  -%]
    [%- END -%]
[%- END -%]
