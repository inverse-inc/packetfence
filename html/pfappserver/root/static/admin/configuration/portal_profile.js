
function submitFormHideModal(modal,form) {
    $.ajax({
        'async' : false,
        'url'   : form.attr('action'),
        'type'  : form.attr('method') || "POST",
        'data'  : form.serialize()
        })
        .always(function()  {
            modal.modal('hide');
        })
        .done(function(data) {
            $(window).hashchange();
        })
        .fail(function(jqXHR) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var status_msg = getStatusMsg(jqXHR);
            showError($('#section h2'), status_msg);
        });
}

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

    save_modal.click(function(event) {
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
    var file_editor_save = $('#file-editor-save');
    var file_editor_reset = $('#file-editor-reset');
    var enableButtonsOnChangeOnce = function(e) {
        cancel_link.attr('data-toggle','modal');
        file_editor_save.removeClass('disabled');
        file_editor_reset.removeClass('disabled');
        editor.removeEventListener("change",enableButtonsOnChangeOnce);
    };

    editor.setTheme("ace/theme/monokai");
    editor.getSession().setMode("ace/mode/html");
    editor.on("change",enableButtonsOnChangeOnce);
    editor.focus();


    $('#resetContent').find('a.btn-primary').first().click(function(event) {
        editor.setValue(file_content.val(),-1);
        cancel_link.removeAttr('data-modal');
        file_editor_save.addClass('disabled');
        file_editor_reset.addClass('disabled');
        editor.on("change",enableButtonsOnChangeOnce);
    });
}

function initEditorPage() {
    var file_content = $('#file_content');
    var editor = ace.edit("editor");
    initVariableList(editor);
    initShowLinesCheckBox(editor);
    initSaveModal(editor,file_content);
    initCancelModal();
    initEditor(editor,file_content);
    $('#section').on('dblclick','#file_name',function(event){
        var that = $(this);
        var input_span = that.next().first();
        var width_span = input_span.next().first();
        var input = input_span.children().first();
        width_span.html(input.val());
        input.width(width_span.width() + 3);
        input_span.removeClass('hidden');
        that.addClass('hidden');
        input.focus();
    });
    $('#new_file_name').keyup(function(event){
        var input = $(this);
        if (event.keyCode == 27) {
            input.focusout();
        } else {
            var width_span = input.closest('span').next().first();
            width_span.html(input.val());
            input.width(width_span.width() + 3);
        }
    });
    $('#new_file_name').focusout(function(event){
        var file_name_span = $('#file_name');
        var input_span = file_name_span.next().first();
        var width_span = input_span.next().first();
        var input = input_span.children().first();
        width_span.html(input.val());
        input.width(width_span.width() + 2);
        input_span.addClass('hidden');
        file_name_span.removeClass('hidden');
        $('#rename_file')[0].reset();
    });
}

function swapClass(elem) {
    var data_swap = elem.attr('data-swap');
    var class_val = elem.attr('class');
    elem.attr('data-swap',class_val);
    elem.attr('class',data_swap);
}

function initSwapClass(element) {
    element.on('show hidden','.collapse',function(event) {
        var that = $(this);
        var tr = that.closest('tr').first();
        swapClass(tr);
        var link = element.find('[data-target="#' + that.attr('id') + '"]');
        link.find('*[data-swap]').each(function(i,elem){
            swapClass($(elem));
        });
        event.stopPropagation();//To stop the event from closing parents
    });
}

function initCopyModal(element) {
    var modal = $('#copyModal');
    var button = modal.find('.btn-primary').first();
    modal.on('hidden',function() {
        $(this).data('modal').$element.removeData();
    });
    button.off("click");
    button.click(function(event) {
        var form = modal.find("#copyModalForm");
        submitFormHideModal(modal,form);
    });
}

function initNewFileModal() {
    var modal = $('#newFileModal');
    var button = modal.find('.btn-primary').first();
    modal.on('hidden',function() {
        $(this).data('modal').$element.removeData();
    });
    button.off("click");
    button.click(function(event) {
        var form = modal.find("#newFileModalForm");
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
    });
}

function initTemplatesPage(element) {
    initCopyModal(element);
    initSwapClass(element);
    initNewFileModal(element);
}

$('#section').on('section.loaded',function(event) {
    var initializers = [
        {id : "#file_editor", initializer: initEditorPage},
        {id : "#portal_profile_files", initializer: initTemplatesPage },
    ];
    for(var i =0; i< initializers.length;i++) {
        var initializer = initializers[i];
        var element = $(initializer.id);
        if(element.length > 0) {
            initializer.initializer(element);
        }
    }

});
