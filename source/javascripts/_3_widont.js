$.domReady(function() {
    $('h1,h2,h3,li,p').each(function() {
        $(this).html($(this).html().replace(/\s((?=(([^\s<>]|<[^>]*>)+))\2)\s*$/,'&nbsp;$1'));
    });
});
