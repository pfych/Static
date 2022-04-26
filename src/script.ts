/** Thank you josh! https://www.joshwcomeau.com/react/dark-mode/ */
function getInitialColorMode() {
  const persistedColorPreference = window.localStorage.getItem("color-mode");
  const hasPersistedPreference = typeof persistedColorPreference === "string";

  if (hasPersistedPreference) {
    return persistedColorPreference;
  }

  const mql = window.matchMedia("(prefers-color-scheme: dark)");
  const hasMediaQueryPreference = typeof mql.matches === "boolean";
  if (hasMediaQueryPreference) {
    return mql.matches ? "dark" : "light";
  }

  return "light";
}

// Thanks https://stackoverflow.com/a/60949881/3673022
const runOnImagesLoad = (func: () => void): void => {
  Promise.all(Array.from(document.images).map(img => {
    if (img.complete) {
      return Promise.resolve(img.naturalHeight !== 0);
    }

    return new Promise(resolve => {
      img.addEventListener('load', () => resolve(true));
      img.addEventListener('error', () => resolve(false));
    });
  })).then(results => {
    if (results.every(res => res)) {
      console.log('all images loaded successfully');
    } else {
      console.log('some images failed to load, all finished loading');
    }

    func()
  });
}

let colourMode = getInitialColorMode() || "light";
const setColourMode = () => {
  colourMode = getInitialColorMode() || "light";
  const root = document.documentElement;

  root.style.setProperty(
    "--colour-text",
    colourMode === "light" ? "#000" : "#fff"
  );

  root.style.setProperty(
    "--colour-background",
    colourMode === "light" ? "#fff" : "#000"
  );

  root.style.setProperty(
    "--colour-background-sub",
    colourMode === "light" ? "#eee" : "#111"
  );
};
setColourMode();

const createSideNotes = () => {
  const body = document.getElementsByClassName("container")[0];
  const footnotes = Array.from(
    document.getElementsByClassName("footnotes")[0].getElementsByTagName("li")
  );

  const rightSidenoteContainer = document.createElement("div");
  const leftSidenoteContainer = document.createElement("div");
  rightSidenoteContainer.className = "rightSidenoteContainer";
  leftSidenoteContainer.className = "leftSidenoteContainer";
  body.appendChild(rightSidenoteContainer);
  body.appendChild(leftSidenoteContainer);

  footnotes.forEach((footnote, i) => {
    const footnoteOrigin = document.getElementById(
      footnote.id.replace("fn", "fnref")
    );
    const sideNote = document.createElement("span");
    const number = document.createElement("span");
    const offset = footnoteOrigin.getBoundingClientRect();
    const footnoteContent = footnote.getElementsByTagName("p")

    number.append(`${footnote.id.replace("fn", "")}.`);
    number.className = "number";

    sideNote.id = `${footnote.id}-side`;
    sideNote.className = "sidenote";
    sideNote.style.top = `${(offset.top - body.getBoundingClientRect().top) - 8 || 0}px`;

    sideNote.appendChild(number);
    Array.from(footnoteContent).forEach((item) => {
      const editItem = item.cloneNode(true) as unknown as HTMLParagraphElement
      const aTags = editItem.getElementsByTagName('a')
      aTags.item(aTags.length - 1).remove();
      sideNote.append(editItem)
    })

    if (i % 2) {
      leftSidenoteContainer.appendChild(sideNote);
    } else {
      rightSidenoteContainer.appendChild(sideNote);
    }
  });
};

document.addEventListener("DOMContentLoaded", function () {
  const heading = document.getElementsByTagName("h1");
  if (heading[0]) {
    let mainHeading = heading[0];
    let controls = document.createElement("span");
    let themeToggle = document.createElement("span");

    themeToggle.setAttribute("role", "button");
    themeToggle.setAttribute("tabIndex", "0");
    themeToggle.setAttribute("class", "themeToggle");
    themeToggle.setAttribute("title", "Change theme");
    themeToggle.append(colourMode === "light" ? " 🌕" : " 🌑");
    themeToggle.onclick = () => {
      window.localStorage.setItem(
        "color-mode",
        colourMode === "light" ? "dark" : "light"
      );
      setColourMode();
      themeToggle.innerHTML = colourMode === "light" ? " 🌕" : " 🌑";
    };

    controls.appendChild(themeToggle);
    mainHeading.append(controls);
  }

  runOnImagesLoad(createSideNotes)
});

