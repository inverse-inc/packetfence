
function initVariableList(editor) {
    $('#variable_list').on('click', '.insert-into-file', function(event) {
        var that = $(this);
        var content = that.attr("data-content");
        editor.insert(content);
        editor.focus();
        return false;
    });
}

function initShowLinesCheckBox(editor) {
    var file_editor_show_lines =  $("#file-editor-show-lines");
    var renderer = editor.renderer;
    file_editor_show_lines.off('click');
    file_editor_show_lines.click(function (e) {
        renderer.setShowGutter(this.checked);
        return true;
    });

    renderer.setShowGutter(file_editor_show_lines.is(':checked'));
}

function initSaveModal(editor,file_content) {
    var save_modal = $("#saveFile");
    var save_button = save_modal.find('a.btn-primary').first();
    save_button.off('click');

    save_button.click(function(event) {
        var form     = $('#file_editor_form');
        file_content.val(editor.getValue());
        submitFormHideModal(save_modal,form);
    });
}

function initCancelModal() {
    $('#cancelEdit').find('a.btn-primary').first().click(function(event) {
        window.location = $(this).attr('href');
    });

}

function initEditor(editor,file_content) {
    var cancel_link = $("#cancel-link");
    var file_editor_buttons = $('.form-actions a.btn.editorToggle');
    var enableButtonsOnChangeOnce = function(e) {
        cancel_link.attr('data-toggle','modal');
        file_editor_buttons.toggleClass('disabled');
        editor.removeEventListener("change",enableButtonsOnChangeOnce);
    };

    editor.setTheme("ace/theme/monokai");
    editor.getSession().setMode("ace/mode/html");
    editor.on("change",enableButtonsOnChangeOnce);
    editor.focus();

    $('#rename_file').on('submit',function () {
        submitFormHideModalGoToLocation($("#renameModal"),$(this));
        return false;
    });

    $('#resetContent').find('a.btn-primary').first().click(function(event) {
        editor.setValue(file_content.val(),-1);
        cancel_link.removeAttr('data-modal');
        file_editor_buttons.toggleClass('disabled');
        editor.on("change",enableButtonsOnChangeOnce);
    });
}

function initRenameForm(element) {
    var file_name_span = $('#file_name');
    var input_span = file_name_span.next().first();
    var link = file_name_span.find("a").first();
    var width_span = input_span.next().first();
    var input = input_span.children().first();
    var rename_form = $('#rename_file');
    element.on('click', '#file_name a',function(event){
        width_span.html(input.val());
        input.width(width_span.width() + 5);
        input_span.removeClass('hidden');
        link.addClass('hidden');
        input.focus();
    });
    $('#new_file_name').keyup(function(event){
        var input = $(this);
        if (event.keyCode == 27) {
            input.focusout();
        } else {
            width_span.html(input.val());
            input.width(width_span.width() + 5);
        }
    });
    $('#new_file_name').focusout(function(event){
        width_span.html(input.val());
        input.width(width_span.width() + 5);
        input_span.addClass('hidden');
        link.removeClass('hidden');
        rename_form[0].reset();
    });
}

function initEditorPage(element) {
    var file_content = $('#file_content');
    var editor = ace.edit("editor");
    initVariableList(editor);
    initShowLinesCheckBox(editor);
    initSaveModal(editor,file_content);
    initCancelModal();
    initEditor(editor,file_content);
    initRenameForm(element);
}

function initCollapse(element) {
    element.on('show hidden','.collapse',function(event) {
        var that = $(this);
        var tr = that.closest('tr').first();
        tr.swap_class('toggle');
        var link = element.find('[data-target="#' + that.attr('id') + '"]');
        link.find('[data-swap]').swap_class('toggle');
        event.stopPropagation(); //To stop the event from closing parents
    });
}

function initCopyModal(element) {
    var modal = $('#copyModal');
    var button = modal.find('.btn-primary').first();
    modal.on('shown', function() {
        $(this).find(':input:first').focus();
    });
    modal.on('hidden', function() {
        $(this).data('modal').$element.removeData();
    });
    button.off("click");
    button.click(function(event) {
        var form = modal.find("#copyModalForm");
        submitFormHideModal(modal,form);
    });

    element.on('submit',"#copyModalForm",function () {
        submitFormHideModal(modal,$(this));
        return false;
    });
}

function submitFormHideModalGoToLocation(modal,form) {
    $.ajax({
        'async' : false,
        'url'   : form.attr('action'),
        'type'  : form.attr('method') || "POST",
        'data'  : form.serialize()
        })
        .always(function()  {
            modal.modal('hide');
        })
        .done(function(data, textStatus, jqXHR) {
            location.hash = jqXHR.getResponseHeader('Location');
        })
        .fail(function(jqXHR) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var status_msg = getStatusMsg(jqXHR);
            showError($('#section h2'), status_msg);
        });
}

function initNewFileModal(element) {
    var modal = $('#newFileModal');
    var button = modal.find('.btn-primary').first();
    modal.on('hidden',function() {
        $(this).data('modal').$element.removeData();
    });
    modal.on('shown', function() {
        $(this).find(':input:first').focus();
    });
    button.off("click");
    button.click(function(event) {
        var form = modal.find("#newFileModalForm");
        submitFormHideModalGoToLocation(modal,form);
        return false;
    });
    element.on('submit',"#newFileModalForm",function () {
        submitFormHideModalGoToLocation(modal,$(this));
        return false;
    });
}

function disabledLinks(element) {
    element.on('click','.disabled',function() { return false;});
}

function initIndexPage(element) {
}

function initCreatePage(element) {
    var form = element.find("#create_profile");
    var saveBtn = form.find('.btn-primary').first();
    saveBtn.off("click");
    saveBtn.click(function(event) {
        var valid = isFormValid(form);
        if(!valid) {
            $("body,html").animate({scrollTop:0}, 'fast');
        }
        return valid;
    });

    var modal = $('#createProfile');
    var confirmationBtn = modal.find('.btn-primary').first();
    confirmationBtn.off("click");
    confirmationBtn.click(function(event) {
        submitFormHideModalGoToLocation(modal, form);
        return false;
    });
    initReadPage(element);
}

function initReadPage(element) {
    updateDynamicRowsAfterRemove($('#locale'));
    updateDynamicRowsAfterRemove($('#filter'));
    $('#locale, #sources').on('admin.added','tr', function(event) {
        var row = $(this);
        var siblings = row.siblings(':not(.hidden)');
        var selected_options = siblings.find("select option:selected");
        var select = row.find("select");
        select.find("option:selected").removeAttr("selected");
        var options = select.find('option[value!=""]');
        // Select the next option that was not yet selected
        try {
            options.each(function(index,element) {
                var selector = '[value="' + element.value   + '"]';
                if(selected_options.filter(selector).length == 0) {
                    $(element).attr("selected", "selected");
                    throw "";
                }
            });
        }
        catch(e) {};
        // If all options have been added, remove the add button
        var rows = row.siblings(':not(.hidden)').andSelf();
        if (rows.length == options.length) {
            rows.find('[href="#add"]').addClass('hidden');
        }
    });
    // When selecting an exclusive source, remove all other sources
    $('#sources').on('change', 'select', function(event) {
        var that = $(this);
        var tr = that.closest('tr');
        if (that.find(':selected').attr('data-source-class') == 'exclusive') {
            tr.siblings(':not(.hidden)').find('[href="#delete"]').click();
            tr.find('[href="#add"]').addClass('hidden');
        } else {
            tr.find('[href="#add"]').removeClass('hidden');
        }
    });
    $('[id$="Empty"]').on('click', '[href="#add"]', function(event) {
        var match = /(.+)Empty/.exec(event.delegateTarget.id);
        var id = match[1];
        var emptyId = match[0];
        $('#'+id).trigger('addrow');
        $('#'+emptyId).addClass('hidden');
        return false;
    });
}

function initTemplatesPage(element) {
    initCopyModal(element);
    initCollapse(element);
    initNewFileModal(element);
}

function portalProfileGlobalInit(element) {
    initWidgets(element.find('.chzn-select'));
    disabledLinks(element);
}

$('#section').on('section.loaded',function(event) {
    var initializers = [
        {id : "#portal_profile_file_editor", initializer: initEditorPage},
        {id : "#portal_profile_files", initializer: initTemplatesPage },
        {id : "#portal_profile_index", initializer: initIndexPage },
        {id : "#portal_profile_create", initializer: initCreatePage },
        {id : "#portal_profile_read", initializer: initReadPage }
    ];
    for (var i = 0; i < initializers.length; i++) {
        var initializer = initializers[i];
        var element = $(initializer.id);
        if (element.length) {
            portalProfileGlobalInit(element);
            initializer.initializer(element);
        }
    }

});
