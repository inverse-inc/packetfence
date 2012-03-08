function initPage() {
    var firstColumn = null;

    // Register events

    $$("ul.tab a").each(function(a) {
        a.observe("click", onClickTab);
    });

    $$("div.column").each(function(d) {
        if (!firstColumn) firstColumn = d;
        registerImportColumn(d);
    });

    $("action_import").observe("click", onImportAction);

    // Initialize states

    $("columns_order").value.split(",").reverse().each(function(c) {
        var r = $$("input[name='" + c + "']");
        if (r.length) {
            var i = r.first();
            i.checked = true;
            d = i.up("div.column");
            var d_new = d.clone(true);
            registerImportColumn(d_new, d);
            firstColumn.parentNode.insertBefore(d_new, firstColumn);
            d.remove();
            firstColumn = d_new;
        }
    });

    $$("div.column input").each(function(i) {
        var s = i.next("span");
        if (!i.checked) {
            s.addClassName("disabled");
        }       
    });

    var initialTab = $$("ul.tab a[name='"+initialTabName+"']");
    if (initialTab) {
        var f = onClickTab.bind(initialTab.first());
        f();
    }
}

function registerImportColumn(d, d_old) {
    var i = d.down("input");
    if (!i.disabled) i.observe("click", onImportColumnClick);
    var imgs = d.select("img");
    imgs[0].observe("click", onImportColumnMoveUp);
    imgs[1].observe("click", onImportColumnMoveDown);
    if (d_old && Prototype.Browser.IE) {
        var i_old = d_old.down("input");
        i.checked = i_old.checked;
    }
}

function onClickTab(event) {
    $$("ul.tab li").each(function(d) {
        d.removeClassName("active");
    });

    this.up("li").addClassName("active");  

    $$("div.tab").each(function(d) {
        d.removeClassName("active");
    });

    var name = this.readAttribute("name");
    var tab = $(name);
    if (tab) {
        tab.addClassName("active");
        var field = tab.down("input.first");
        if (field)
            field.focus();
    }
    if (event)
        Event.stop(event);
}

function onImportColumnClick(event) {
    if (this.checked)
        this.next("span").removeClassName("disabled");
    else
        this.next("span").addClassName("disabled");
}

function onImportColumnMoveUp(event) {
    var d = this.up("div.column");
    var d_up = d.previous("div.column");
    if (d_up) {
        var d_new = d.clone(true);
        registerImportColumn(d_new, d);
        d_up.parentNode.insertBefore(d_new, d_up);
        d.remove();
    }
}

function onImportColumnMoveDown(event) {
    var d = this.up("div.column");
    var d_down = d.next("div.column");
    if (d_down) {
        var d_new = d_down.clone(true);
        registerImportColumn(d_new, d_down);
        d.parentNode.insertBefore(d_new, d);
        d_down.remove();
    }
}

function onImportAction(event) {
    var c = $("columns").select("input");
    var c_filtered = new Array();
    c.each(function(i) {
        if (i.checked) c_filtered.push(i.readAttribute("name"));
    });
    $("columns_order").value = c_filtered.join(",");

    return true;
}

document.observe("dom:loaded", initPage);