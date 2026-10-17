(function () {
  var root = document.currentScript.src.replace(/lang\.js(\?.*)?$/, "");
  var dirs = { "zh-Hans": "", "zh-Hant": "zh-hant/", "en": "en/" };

  function detect() {
    var langs = navigator.languages || [navigator.language || ""];
    for (var i = 0; i < langs.length; i++) {
      var l = (langs[i] || "").toLowerCase();
      if (l.indexOf("zh") === 0) {
        return /hant|tw|hk|mo/.test(l) ? "zh-Hant" : "zh-Hans";
      }
      if (l.indexOf("en") === 0) return "en";
    }
    return "en";
  }

  var saved = null;
  try { saved = localStorage.getItem("lang"); } catch (e) {}
  var want = dirs.hasOwnProperty(saved) ? saved : detect();
  var current = document.documentElement.lang;

  if (want !== current) {
    var page = /privacy\.html$/.test(location.pathname) ? "privacy.html" : "";
    location.replace(root + dirs[want] + page + location.hash);
    return;
  }

  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest("nav.lang a[hreflang]");
    if (!a) return;
    try { localStorage.setItem("lang", a.getAttribute("hreflang")); } catch (err) {}
  });
})();
