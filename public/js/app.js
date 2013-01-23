(function () {
  $(function () {
    var inputs, shortcut, last;
    inputs   = $("form:first input[type=text]");
    shortcut = $("form:last input:first");

    setInterval(function () {
      var url, params;
      params = [];
      inputs.each(function () {
        var $this, k, v;
        $this = $(this);
        k = $this.attr("name");
        v = $this.val().trim();
        if (v.length > 0) {
          params.push(k + "=" + encodeURIComponent(v));
        }
      });
      url = document.location.protocol + "://" + document.location.host + "/?";
      url += params.join("&");
      if (last !== url) {
        last = url;
        shortcut.val(url);
      }
    }, 500);
  });
}());
