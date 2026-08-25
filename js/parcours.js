"use strict";
// ------------------------------------------------------------------
// L'ÉCRAN DU RUBAN — un seul bouton, « Continuer ».
// ------------------------------------------------------------------
// Remplace js/carte.js (lot D, 25 août 2026), qui montrait un graphe de hubs
// et faisait choisir une direction. Sur un ruban il n'y a rien à choisir : la
// prochaine gare est la prochaine gare.
//
// Ce fichier est la forme MINIMALE de l'écran décrit au §4 quater du document
// (le chapitre en cours, la gare en évidence, le relevé, le voyage). Ce qui
// manque encore et qui est le lot E : la carte d'Europe posée sur la gare
// courante, avec sa caméra. Le vocabulaire visuel (.c-tete, .c-ligne, .jalon,
// .c-bilan) est celui de l'ancienne vue ligne — la feuille de style ne bouge
// pas, et js/carte.js reste au dépôt le temps que le lot E en reprenne la
// projection et la caméra.
// ------------------------------------------------------------------

const CARTE = { hote: null, vue: "ligne", bilan: null, voyage: null, prochaine: null, etoiles: null };

function nomDe(id) { const c = cardOf(id); return c ? (c.city || c.name) : id; }
function etoilesDe(id) { return ((getProgress()[id] || {}).stars) || 0; }

// L'état d'une gare, tel que le ruban le montre. Quatre états, et ils
// s'excluent : faite, payée (franchie sans étoile), courante (le pas suivant),
// à venir.
function etatDeGare(id) {
  if (!estEcrite(id)) return "avenir";
  if (estFaite(id)) return "tenue";
  if (estPassee(id)) return "payee";
  const i = indexDe(id);
  return i >= 0 && i <= positionCourante() ? "ouvrable" : "fermee";
}

// ------------------------------------------------------------------
// LA BULLE DU RÉSULTAT — sous la gare qu'on vient de tenir.
// ------------------------------------------------------------------
// Elle ne dit que ce que les étoiles ne disent pas : le retard, et ce qu'il
// vaut face au record. Les boutons y sont posés, parce que le regard est déjà
// là — il n'a pas à descendre au bas de l'écran.
function bilanHTML(suite) {
  const b = CARTE.bilan;
  if (!b) return "";
  const cl = "c-bilan" + (b.perfect ? " parfait" : "") + (b.win ? "" : " rate");
  const etoiles = typeof etoilesHTML === "function" ? etoilesHTML(b.stars, b.prevStars) : "";
  const retard = b.failed
    ? `<div class="cb-retard"><b>${b.d}</b> min — plafond dépassé</div>`
    : `<div class="cb-retard"><b>${b.d}</b> min de retard</div>`;
  let rec = "";
  if (b.failed) rec = "";
  else if (!b.win) rec = `<div class="cb-record loin">objectif manqué</div>`;
  else if (b.prevBest == null) rec = `<div class="cb-record neuf">premier service</div>`;
  else if (b.d < b.prevBest) rec = `<div class="cb-record bat">record battu · −${b.prevBest - b.d} min</div>`;
  else if (b.d === b.prevBest) rec = `<div class="cb-record egal">record égalé</div>`;
  else rec = `<div class="cb-record loin">record : ${b.prevBest} min</div>`;
  return `<div class="${cl}" role="status"><div class="cb-etoiles">${etoiles}</div>${retard}${rec}${suite || ""}</div>`;
}
// La bulle se pose APRÈS le rendu, parce qu'elle se mesure : centrée sous le
// jalon, à la hauteur de ses petites étoiles (qu'elle remplace).
function poserBilan() {
  if (!CARTE.hote) return;
  const bulle = CARTE.hote.querySelector(".c-bilan");
  const jalon = CARTE.hote.querySelector(".jalon.j-bilan");
  if (!bulle || !jalon) { if (bulle) bulle.remove(); return; }
  const et = jalon.querySelector(".etoiles");
  const piste = jalon.parentElement;
  const haut = (et ? et.offsetTop + et.offsetHeight : jalon.offsetHeight) + 6;
  const depasse = bulle.offsetHeight - (jalon.offsetHeight - haut);
  piste.style.paddingBottom = Math.max(0, depasse) + "px";
  bulle.style.left = (jalon.offsetLeft + jalon.offsetWidth / 2) + "px";
  bulle.style.top = (jalon.offsetTop + haut) + "px";
  if (!CARTE.voyage && piste.scrollWidth > piste.clientWidth) {
    const cx = jalon.offsetLeft + jalon.offsetWidth / 2;
    piste.scrollTo({ left: Math.max(0, cx - piste.clientWidth / 2) });
  }
}
window.addEventListener("resize", () => { if (CARTE.bilan) poserBilan(); });

// ------------------------------------------------------------------
// LE VOYAGE — un train qui roule jusqu'à la gare suivante.
// ------------------------------------------------------------------
// Le relevé désigne une gare par son nom ; la piste la marque d'un halo. Entre
// les deux, le joueur devrait faire lui-même le lien entre un mot et un point.
// Le train le fait à sa place : le trajet EST la phrase.
function animerVoyage() {
  const de = CARTE.voyage;
  CARTE.voyage = null;
  if (!de || !CARTE.hote) return;
  const vers = CARTE.prochaine;
  if (!vers || vers === de) return;
  const piste = CARTE.hote.querySelector(".c-ligne");
  if (!piste) return;
  const a = piste.querySelector('[data-gare="' + de + '"]');
  const b = piste.querySelector('[data-gare="' + vers + '"]');
  if (!a || !b) return;
  if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  const centre = el => el.offsetLeft + el.offsetWidth / 2;
  const x0 = centre(a), x1 = centre(b);
  const train = document.createElement("div");
  train.className = "c-train";
  train.textContent = x1 >= x0 ? "▸" : "◂";
  train.style.top = (a.offsetTop + 21) + "px";
  piste.appendChild(train);
  const duree = Math.max(420, Math.min(1100, Math.abs(x1 - x0) * 3.2));
  const anim = train.animate(
    [{ transform: "translateX(" + x0 + "px)", opacity: 0 },
     { transform: "translateX(" + x0 + "px)", opacity: 1, offset: 0.12 },
     { transform: "translateX(" + x1 + "px)", opacity: 1 }],
    { duration: duree, easing: "cubic-bezier(.4,0,.25,1)", fill: "forwards" });
  if (piste.scrollWidth > piste.clientWidth)
    piste.scrollTo({ left: Math.max(0, x1 - piste.clientWidth / 2), behavior: "smooth" });
  anim.onfinish = () => {
    train.remove();
    b.classList.add("arrivee");
    setTimeout(() => b.classList.remove("arrivee"), 900);
  };
}

// ------------------------------------------------------------------
// LES COMPTEURS — grade, étoiles, série, et le solde de crédits.
// ------------------------------------------------------------------
function bourseHTML() {
  if (typeof gradeOf !== "function" || typeof etoilesTotal !== "function") return "";
  const n = etoilesTotal(), g = gradeOf(n);
  const s = typeof getSerie === "function" ? getSerie() : { n: 0 };
  const cr = typeof soldeCredits === "function" ? soldeCredits() : null;
  return `<div class="c-compteurs">` +
    (s.n >= 2 ? `<span class="c-serie" title="${s.n} services d'affilée sous dix minutes">» ${s.n}</span>` : "") +
    `<span class="c-grade" title="${g.nom}">` +
      `<span class="g-nom">${g.nom}</span>` +
      `<span class="g-jauge"><i style="width:${Math.round(g.part * 100)}%"></i></span></span>` +
    (cr === null ? "" : `<span class="c-credits" title="crédits">◆ ${cr}</span>`) +
    `<span class="c-etoiles">★ ${n}</span></div>`;
}

const FLECHE = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" ' +
  'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
  '<path d="M5 12h13M12 6l6 6-6 6"/></svg>';
const BOUCLE = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" ' +
  'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
  '<path d="M20 11.5A8 8 0 1 1 17.4 6L20 8.5"/><path d="M20 4v5h-5"/></svg>';

// ------------------------------------------------------------------
// LA VUE DU RUBAN.
// ------------------------------------------------------------------
function vueRuban() {
  const gc = gareCourante();
  // On montre le chapitre de la gare courante ; à défaut (ruban fini, ou
  // arrêté faute de contenu) celui de la dernière gare franchie.
  const pos = Math.min(positionCourante(), Math.max(0, longueurDuRuban() - 1));
  const ch = chapitreDeGare(gc) || chapitreAt(pos);
  if (!ch) return `<div class="c-tete"><div class="c-titre">Aucun chapitre n'est encore écrit</div></div>`;

  CARTE.prochaine = gc;
  const rang = typeof rangDeChapitre === "function" ? rangDeChapitre(ch) : null;
  const faits = ch.gares.filter(g => estFaite(g)).length;
  const total = ch.gares.length;
  const zone = typeof zoneById === "function" ? zoneById(ch.zone) : null;
  const chs = chapitresDuRuban();
  const suivant = chs[ch.rang + 1] || null;

  const jalon = id => {
    const etat = etatDeGare(id);
    const bilan = CARTE.bilan && CARTE.bilan.gare === id;
    const cl = ["jalon", "j-" + etat, bilan ? "j-bilan" : ""].filter(Boolean).join(" ");
    const st = etoilesDe(id);
    const courante = id === gc;
    const jouable = etat === "tenue" || etat === "ouvrable" || etat === "payee";
    return `<button class="${cl}" data-gare="${id}"${jouable ? "" : " disabled"}` +
      `${courante ? ' data-suivante="1"' : ""}>` +
      `<span class="pastille"></span>` +
      `<span class="nom">${nomDe(id)}</span>` +
      `<span class="etoiles">${st ? "★".repeat(st) : (etat === "payee" ? "·" : "")}</span>` +
      `</button>`;
  };

  // LE BOUTON D'APPEL — le seul geste de l'écran. Sous la piste d'ordinaire,
  // DANS la bulle quand un service vient de finir.
  const b = CARTE.bilan;
  const rate = !!(b && !b.win);
  let suiteBulle = "";
  if (rate) {
    // ÉCHEC : deux issues côte à côte, jamais l'une à la place de l'autre.
    // Réessayer est gratuit, immédiat et sans limite ; payer le passage coûte
    // des crédits et ne donne pas d'étoile (§4 ter).
    const prix = typeof prixDePassage === "function" ? prixDePassage(b.gare) : 0;
    const solde = typeof soldeCredits === "function" ? soldeCredits() : 0;
    const assez = solde >= prix;
    suiteBulle =
      `<button class="c-suite cb-suite cb-rejouer" data-gare="${b.gare}" title="${nomDe(b.gare)}">Réessayer${BOUCLE}</button>` +
      `<button class="c-suite cb-suite cb-payer" data-payer="${b.gare}"${assez ? "" : " disabled"}` +
      ` title="${assez ? "Passer cette gare sans étoile" : "Il te manque " + (prix - solde) + " crédits"}">` +
      `Passer · ◆ ${prix}</button>`;
  } else if (b && gc) {
    suiteBulle = `<button class="c-suite cb-suite" data-gare="${gc}" title="${nomDe(gc)}">Continuer${FLECHE}</button>` +
      `<button class="c-suite cb-suite cb-rejouer" data-gare="${b.gare}" title="${nomDe(b.gare)}">Rejouer${BOUCLE}</button>`;
  } else if (b) {
    suiteBulle = `<button class="c-suite cb-suite cb-rejouer" data-gare="${b.gare}" title="${nomDe(b.gare)}">Rejouer${BOUCLE}</button>`;
  }
  const suite = !b && gc
    ? `<button class="c-suite" data-gare="${gc}">Continuer vers ${nomDe(gc)}${FLECHE}</button>`
    : (!b && auBoutDeLEcrit()
      ? `<div class="c-avenir">La suite du ruban n'est pas encore écrite.</div>` : "");

  // Le cartouche : le chapitre, où l'on en est, et ce qui vient après.
  const apres = suivant ? `<span class="c-apres">puis ${suivant.nom}</span>` : "";
  const sautHTML = ch.saut
    ? `<div class="c-saut"><b>Saut · ${ch.saut.mode}</b>${ch.saut.texte}</div>` : "";

  return `
    <div class="c-tete">
      <button class="c-zoom" data-vue="ligne">${zone ? zone.nom : "Le ruban"}</button>
      <div class="c-titre"><span class="c-nom">${ch.nom}</span>${rang
        ? `<span class="c-rang r-${rang.id}">${rang.nom}</span>`
        : `<span class="c-avance">${faits} / ${total}</span>`}${apres}</div>
      ${bourseHTML()}
    </div>
    ${sautHTML}
    <div class="c-groupe">
      <div class="c-ligne${CARTE.bilan ? " avec-bilan" : ""}"${rang ? ` data-rang="${rang.id}"` : ""}>
        ${ch.gares.map(jalon).join("")}
        ${bilanHTML(suiteBulle)}
      </div>
      ${CARTE.bilan ? "" : suite}
    </div>`;
}

// ------------------------------------------------------------------
// RENDU ET GESTES.
// ------------------------------------------------------------------
function renderCarte() {
  const hote = document.getElementById("hub-map");
  if (!hote) return;
  CARTE.hote = hote;
  hote.className = "carte v-ligne";
  hote.innerHTML = vueRuban();
  CARTE.etoiles = hote.querySelector(".c-etoiles");
  poserBilan();     // avant le voyage : lui lit CARTE.voyage, et le consomme
  animerVoyage();

  hote.onclick = ev => {
    const pay = ev.target.closest("[data-payer]");
    if (pay && !pay.disabled) { passerLaGare(pay.dataset.payer); return; }
    const g = ev.target.closest("[data-gare]");
    if (g && g.dataset.gare && !g.disabled) { jouerGare(g.dataset.gare); return; }
  };
}

// Un seul geste sur une gare : la jouer. Sur un ruban il n'y a rien à ouvrir —
// une gare est atteinte ou elle ne l'est pas, et le bouton est alors désactivé.
function jouerGare(gareId) {
  const i = CATALOG.findIndex(c => c.id === gareId);
  if (i < 0) return;
  if (!estTenue(gareId)) { renderCarte(); return; }
  startStation(i);
}
// PASSER EN PAYANT (§4 ter). La gare reste à zéro étoile — elle ne compte ni
// pour la jauge, ni pour le rang, ni pour une médaille — et se rejoue quand on
// veut : la gagner plus tard rend la mise, puisque la dépense ne compte que
// les gares passées ENCORE à zéro étoile.
function passerLaGare(gareId) {
  if (typeof payerPassage !== "function" || !gareId) return;
  const prix = typeof prixDePassage === "function" ? prixDePassage(gareId) : 0;
  if ((typeof soldeCredits === "function" ? soldeCredits() : 0) < prix) return;
  if (!payerPassage(gareId)) return;
  CARTE.bilan = null;
  CARTE.voyage = gareId;          // le train part quand même : on avance
  renderCarte();
}
