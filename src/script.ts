/** Thank you josh! https://www.joshwcomeau.com/react/dark-mode/ */
function getInitialColorMode() {
  const persistedColorPreference = window.localStorage.getItem('color-mode');
  const hasPersistedPreference = typeof persistedColorPreference === 'string';

  if (hasPersistedPreference) {
    return persistedColorPreference;
  }

  const mql = window.matchMedia('(prefers-color-scheme: dark)');
  const hasMediaQueryPreference = typeof mql.matches === 'boolean';
  if (hasMediaQueryPreference) {
    return mql.matches ? 'dark' : 'light';
  }

  return 'light';
}

const getInitialAlign = () => {
  const persistedAlignPreference = window.localStorage.getItem('align-mode');
  const hasPersistedPreference = typeof persistedAlignPreference === 'string';

  if (hasPersistedPreference) {
    return persistedAlignPreference;
  }

  return 'left';
}

let colourMode = getInitialColorMode() || 'light';
const setColourMode = () => {
  colourMode = getInitialColorMode() || 'light';
  const root = document.documentElement;

  root.style.setProperty(
    '--colour-text',
    colourMode === 'light' ? '#000' : '#fff'
  );

  root.style.setProperty(
    '--colour-background',
    colourMode === 'light' ? '#fff' : '#000'
  );

  root.style.setProperty(
    '--colour-background-sub',
    colourMode === 'light' ? '#eee' : '#111'
  );
}

let alignMode = getInitialAlign() || 'left';
const setAlignMode = () => {
  alignMode = getInitialAlign() || 'left';
  const root = document.documentElement;

  root.style.setProperty(
    '--container-margin',
    alignMode === 'left' ? '0' : 'auto'
  );
}

setColourMode();
setAlignMode();

document.addEventListener("DOMContentLoaded", function(){
  const heading = document.getElementsByTagName("h1")
  if (heading[0]) {
    let mainHeading = heading[0];
    let controls = document.createElement('span')
    let themeToggle = document.createElement('span');
    let marginToggle = document.createElement('span');

    themeToggle.setAttribute('role', 'button')
    themeToggle.setAttribute('tabIndex', '0')
    themeToggle.setAttribute('class', 'themeToggle')
    themeToggle.append(colourMode === 'light' ? " 🌕" : " 🌑");
    themeToggle.onclick = () => {
      window.localStorage.setItem(
        'color-mode',
        colourMode === 'light' ? 'dark' : 'light'
      );
      setColourMode()
      themeToggle.innerHTML = colourMode === 'light' ? " 🌕" : " 🌑"
    }

    marginToggle.setAttribute('role', 'button')
    marginToggle.setAttribute('tabIndex', '0')
    marginToggle.setAttribute('class', 'alignToggle')
    marginToggle.append(alignMode === 'left' ? '➡️' : '⬅️')
    marginToggle.onclick = () => {
      window.localStorage.setItem(
        'align-mode',
        alignMode === 'left' ? 'center' : 'left'
      );
      setAlignMode()
      marginToggle.innerHTML = alignMode === 'left' ? '➡️' : '⬅️'
    }

    controls.appendChild(themeToggle)
    controls.appendChild(marginToggle)
    mainHeading.append(controls)
  }
});
