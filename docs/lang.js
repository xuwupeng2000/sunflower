(function () {
  var root = new URL(".", document.currentScript.src).href;
  var dirs = { "zh-Hans": "", "zh-Hant": "zh-hant/", "en": "en/", "ja": "ja/", "ko": "ko/", "de": "de/", "fr": "fr/", "it": "it/", "es": "es/", "ru": "ru/" };
  function detect() {
    var langs = navigator.languages || [navigator.language || ""];
    for (var i = 0; i < langs.length; i++) {
      var lang = (langs[i] || "").toLowerCase();
      if (lang.indexOf("zh") === 0) return /hant|tw|hk|mo/.test(lang) ? "zh-Hant" : "zh-Hans";
      var base = lang.split(/[-_]/)[0];
      if (Object.prototype.hasOwnProperty.call(dirs, base)) return base;
    }
    return "en";
  }
  var saved;
  try { saved = localStorage.getItem("lang"); } catch (e) {}
  var want = Object.prototype.hasOwnProperty.call(dirs, saved) ? saved : detect();
  // Explicit language links from the store stay in that language. Only the root auto-selects.
  var rootPath = new URL(root).pathname;
  var atRoot = location.pathname === rootPath || location.pathname === rootPath + "index.html";
  if (atRoot && want !== document.documentElement.lang) {
    location.replace(root + dirs[want] + location.hash);
    return;
  }
  var tracker = document.createElement("script");
  tracker.defer = true;
  tracker.src = "https://cloud.umami.is/script.js";
  tracker.setAttribute("data-website-id", "592c511d-7af7-4aef-a215-2c7a1019bbd2");
  document.head.appendChild(tracker);
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest("nav.lang a[hreflang]");
    if (!a) return;
    try { localStorage.setItem("lang", a.getAttribute("hreflang")); } catch (err) {}
  });
})();
