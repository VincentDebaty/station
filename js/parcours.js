"use strict";
// ------------------------------------------------------------------
// L'ÉCRAN DU RUBAN — la carte posée sur la gare en cours.
// ------------------------------------------------------------------
// Lot E (25 août 2026), §4 quater du document. L'enchaînement est celui que
// Vincent a décrit : on ouvre le jeu et la caméra est POSÉE SUR LA PROCHAINE
// GARE, mise en évidence, avec ses infos de base ; on appuie sur Continuer ;
// on joue ; le relevé tombe ; la caméra glisse le long du rail jusqu'à la
// gare suivante. Il n'y a jamais rien à choisir.
//
// UNE SEULE CARTE, UNE CAMÉRA — repris de l'ancienne vue carte (js/carte.js,
// lot 2) : tout est dessiné dans la MÊME projection, et trois niveaux ne sont
// que trois positions de caméra. Le CSS fait le trajet (.monde, transition).
//
//   gare      k élevé   la gare en cours et ses voisines
//   chapitre  k moyen   le chapitre entier, du départ à sa grande gare
//   carte     k = 1     le ruban d'un bout à l'autre
//
// LE FOND EST UN FOND, LE RUBAN EST LE SUJET. L'ancienne carte coloriait les
// pays par zone : sur un ruban, c'est le FIL qui porte la couleur, et le
// continent redevient ce qu'il doit être — de quoi savoir où l'on est.
// ------------------------------------------------------------------

const CARTE = {
  hote: null, vue: "gare", bilan: null, voyage: null, prochaine: null,
  etoiles: null, cam: null, camAvant: null, fete: null
};

const RAD = Math.PI / 180;
const CADRE_L = 160, CADRE_H = 100;
const PAYS_HORS_CARTE = new Set(["ISL", "SJM", "FRO", "GRL"]);
const ETIREMENT_X = 1.6;   // l'Europe est plus haute que large : on l'élargit

function nomDe(id) { const c = cardOf(id); return c ? (c.city || c.name) : id; }
function villeDe(id) { const c = cardOf(id); return c ? (c.name || c.city) : id; }
function etoilesDe(id) { return ((getProgress()[id] || {}).stars) || 0; }
function coordDe(id) {
  if (typeof GEO === "undefined" || !GEO.countries) return null;
  for (const p of Object.values(GEO.countries)) {
    const ll = (p.cities || {})[id];
    if (ll) return ll;
  }
  return null;
}
// Quatre états, et ils s'excluent.
function etatDeGare(id) {
  if (!estEcrite(id)) return "avenir";
  if (estFaite(id)) return "faite";
  if (estPassee(id)) return "payee";
  const i = indexDe(id);
  return i >= 0 && i <= positionCourante() ? "courante" : "fermee";
}

// ------------------------------------------------------------------
// LA PROJECTION — cadrée sur le ruban, pas sur le continent.
// ------------------------------------------------------------------
// Une carte se cadre sur ce qu'elle montre. Le ruban ne traverse pour l'instant
// qu'une bande du continent : la cadrer sur l'Europe entière laisserait le fil
// tassé dans un coin. On prend donc la boîte des gares, élargie de moitié pour
// que le pays autour se voie.
let _proj = null, _projPour = null;
function projection() {
  const ordre = ordreDuRuban();
  if (_proj && _projPour === ordre.length) return _proj;
  let lo0 = Infinity, lo1 = -Infinity, la0 = Infinity, la1 = -Infinity;
  for (const g of ordre) {
    const ll = coordDe(g); if (!ll) continue;
    lo0 = Math.min(lo0, ll[0]); lo1 = Math.max(lo1, ll[0]);
    la0 = Math.min(la0, ll[1]); la1 = Math.max(la1, ll[1]);
  }
  if (!isFinite(lo0)) return null;
  const mx = Math.max(2, (lo1 - lo0) * 0.35), my = Math.max(1.5, (la1 - la0) * 0.30);
  lo0 -= mx; lo1 += mx; la0 -= my; la1 += my;
  const cosm = Math.cos((la0 + la1) / 2 * RAD);
  const s = Math.min((CADRE_L - 12) / Math.max((lo1 - lo0) * cosm * ETIREMENT_X, 1),
                     (CADRE_H - 12) / Math.max(la1 - la0, 1));
  _projPour = ordre.length;
  return (_proj = {
    X: lon => CADRE_L / 2 + (lon - (lo0 + lo1) / 2) * cosm * s * ETIREMENT_X,
    Y: lat => CADRE_H / 2 - (lat - (la0 + la1) / 2) * s,
    s
  });
}
function pos(id) {
  const P = projection(), ll = coordDe(id);
  return P && ll ? { x: P.X(ll[0]), y: P.Y(ll[1]) } : null;
}

// ------------------------------------------------------------------
// LA CAMÉRA. Trois niveaux, trois boîtes à cadrer.
// ------------------------------------------------------------------
function fenetreVisible() {
  const svg = CARTE.hote && CARTE.hote.querySelector(".c-graphe");
  let w = 0, h = 0;
  if (svg) { const r = svg.getBoundingClientRect(); w = r.width; h = r.height; }
  const a = w > 0 && h > 0 ? w / h : CADRE_L / CADRE_H;
  return a >= CADRE_L / CADRE_H ? { w: CADRE_H * a, h: CADRE_H } : { w: CADRE_L, h: CADRE_L / a };
}
function zoomPour(bw, bh, marge, kMax) {
  const f = fenetreVisible();
  return Math.max(1, Math.min(kMax, (f.w - 2 * marge) / Math.max(bw, 1), (f.h - 2 * marge) / Math.max(bh, 1)));
}
function boite(ids) {
  let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
  for (const g of ids) { const p = pos(g); if (!p) continue;
    x0 = Math.min(x0, p.x); x1 = Math.max(x1, p.x); y0 = Math.min(y0, p.y); y1 = Math.max(y1, p.y); }
  if (!isFinite(x0)) return null;
  return { x: (x0 + x1) / 2, y: (y0 + y1) / 2, w: x1 - x0, h: y1 - y0 };
}
// La caméra que la vue courante demande.
function cameraVoulue() {
  const gc = CARTE.prochaine || gareCourante();
  const ch = chapitreDeGare(gc) || chapitreAt(Math.min(positionCourante(), longueurDuRuban() - 1));
  if (CARTE.vue === "carte") {
    const b = boite(ordreDuRuban());
    return b ? { x: b.x, y: b.y, k: zoomPour(b.w, b.h, 8, 3) } : { x: CADRE_L / 2, y: CADRE_H / 2, k: 1 };
  }
  if (CARTE.vue === "chapitre" && ch) {
    const b = boite(ch.gares);
    return b ? { x: b.x, y: b.y, k: zoomPour(b.w, b.h, 16, 3.2) } : { x: CADRE_L / 2, y: CADRE_H / 2, k: 1 };
  }
  // LA GARE — le niveau par défaut, celui sur lequel le jeu s'ouvre. On cadre
  // la gare en cours ET ses deux voisines : voir d'où l'on vient et où l'on va
  // est ce qui fait comprendre qu'on avance.
  const i = gc ? indexDe(gc) : Math.max(0, positionCourante() - 1);
  const autour = [gareAt(i - 2), gareAt(i - 1), gareAt(i), gareAt(i + 1), gareAt(i + 2)].filter(Boolean);
  const b = boite(autour.length ? autour : ordreDuRuban().slice(0, 5));
  if (!b) return { x: CADRE_L / 2, y: CADRE_H / 2, k: 1 };
  const p = pos(gc) || b;
  // Pas tout à fait sur la gare : deux tiers sur elle, un tiers sur le groupe
  // qu'elle traverse. Centrée strictement, elle laissait la moitié de l'écran
  // vide du côté d'où l'on vient — et le ruban ne se lisait plus.
  return { x: p.x * 0.62 + b.x * 0.38, y: p.y * 0.62 + b.y * 0.38,
           k: zoomPour(Math.max(b.w, 10), Math.max(b.h, 8), 20, 4.5) };
}

// ------------------------------------------------------------------
// LE FOND — les pays, sans frontière et sans couleur.
// ------------------------------------------------------------------
let _fond = null;
function fondHTML() {
  if (_fond !== null) return _fond;
  const P = projection();
  if (!P || typeof WORLDMAP === "undefined" || !WORLDMAP.countries) return (_fond = "");
  const out = [];
  for (const c of WORLDMAP.countries) {
    if (c.cont !== "europe" || PAYS_HORS_CARTE.has(c.iso)) continue;
    const d = [];
    for (const r of c.r || []) {
      if (r.length < 8) continue;
      let s = "";
      for (let i = 0; i + 1 < r.length; i += 2)
        s += (i ? "L" : "M") + P.X(r[i]).toFixed(1) + " " + P.Y(r[i + 1]).toFixed(1);
      d.push(s + "Z");
    }
    if (d.length) out.push('<path class="pays" d="' + d.join(" ") + '"/>');
  }
  return (_fond = '<g class="fond">' + out.join("") + "</g>");
}

// ------------------------------------------------------------------
// LE RUBAN DESSINÉ.
// ------------------------------------------------------------------
function couleurDeZone(zid) {
  const z = typeof zoneById === "function" ? zoneById(zid) : null;
  return (z && z.couleur) || "#2dd4bf";
}
function railHTML() {
  const ordre = ordreDuRuban(), P = projection();
  if (!P || ordre.length < 2) return "";
  const segs = [];
  for (let i = 1; i < ordre.length; i++) {
    const a = pos(ordre[i - 1]), b = pos(ordre[i]);
    if (!a || !b) continue;
    const ch = chapitreDeGare(ordre[i]);
    const ecrit = estEcrite(ordre[i - 1]) && estEcrite(ordre[i]);
    const fait = estFranchie(ordre[i - 1]) && estFranchie(ordre[i]);
    const cl = "seg " + (!ecrit ? "s-avenir" : fait ? "s-fait" : "s-reste");
    const saut = ch && ch.saut && ch.gares[0] === ordre[i] ? " s-saut" : "";
    segs.push(`<path class="${cl}${saut}" style="--col:${couleurDeZone(ch && ch.zone)}"` +
      ` d="M${a.x.toFixed(1)} ${a.y.toFixed(1)}L${b.x.toFixed(1)} ${b.y.toFixed(1)}"/>`);
  }
  return '<g class="rail">' + segs.join("") + "</g>";
}
// LES SYMBOLES SE DESSINENT À TAILLE D'ÉCRAN. Un rayon en unités du monde
// grossit avec le zoom : à ×7, un point de gare faisait une soucoupe et son
// nom disparaissait dessous. On divise donc rayons et décalages par k — les
// traits, eux, le font en CSS (calc(px / var(--k))).
function garesHTML() {
  const k = (CARTE.cam && CARTE.cam.k) || 1;
  const R = n => (n / k).toFixed(2);
  const ordre = ordreDuRuban(), gc = CARTE.prochaine;
  const chCourant = chapitreDeGare(gc) || chapitreAt(Math.min(positionCourante(), longueurDuRuban() - 1));
  const out = [];
  for (const g of ordre) {
    const p = pos(g); if (!p) continue;
    const etat = etatDeGare(g);
    const ch = chapitreDeGare(g);
    const fin = ch && ch.gares[ch.gares.length - 1] === g;   // la grande gare
    const ici = g === gc;
    const dansChapitre = ch === chCourant;
    const st = etoilesDe(g);
    const cl = ["gare", "g-" + etat, fin ? "g-fin" : "", ici ? "g-ici" : "",
                dansChapitre ? "g-proche" : "", CARTE.bilan && CARTE.bilan.gare === g ? "g-bilan" : ""]
      .filter(Boolean).join(" ");
    const jouable = etat === "faite" || etat === "courante" || etat === "payee";
    const cx = p.x.toFixed(2), cy = p.y.toFixed(2);
    out.push(`<g class="${cl}" style="--col:${couleurDeZone(ch && ch.zone)}"` +
      (jouable ? ` data-gare="${g}" tabindex="0"` : "") + `>` +
      (ici ? `<circle class="halo" cx="${cx}" cy="${cy}" r="${R(fin ? 5.2 : 4.4)}"/>` : "") +
      `<circle class="cible" cx="${cx}" cy="${cy}" r="${R(5.5)}"/>` +
      `<circle class="pt" cx="${cx}" cy="${cy}" r="${R(fin ? 2.3 : 1.5)}"/>` +
      `<text x="${cx}" y="${(p.y - (fin ? 6 : 4.4) / k).toFixed(2)}">${nomDe(g)}</text>` +
      (st ? `<text class="et" x="${cx}" y="${(p.y + 6.2 / k).toFixed(2)}">${"★".repeat(st)}</text>` : "") +
      `</g>`);
  }
  return '<g class="gares">' + out.join("") + "</g>";
}

// ------------------------------------------------------------------
// LE CARTOUCHE — la gare en cours, et ce qu'il faut en savoir.
// ------------------------------------------------------------------
// « On voit la carte zoomée sur la gare en question, en évidence, avec les
// infos de base. » Les infos de base d'une gare d'aiguillage, ce sont ses
// QUAIS et ses DIRECTIONS : c'est de là que vient la difficulté (§2.1), et
// c'est ce que le joueur doit anticiper avant de prendre le service.
function pipsHTML(d) {
  const n = Math.max(1, Math.min(5, d || 1));
  return '<span class="dif">' + Array.from({ length: 5 },
    (_, i) => '<span class="b' + (i < n ? " on" : "") + '"></span>').join("") + "</span>";
}
function cartoucheHTML(gareId) {
  const cfg = cardOf(gareId);
  if (!cfg) return "";
  const ch = chapitreDeGare(gareId);
  const rang = rangDansChapitre(gareId), total = ch ? ch.gares.length : 0;
  const d = difficulteDeGare(gareId, cfg);
  const quais = (cfg.platforms || []).length;
  // `portals` est un OBJET { NOM: {side, color, abbr} } — une direction par clé.
  const dirs = Object.keys(cfg.portals || {}).length;
  const st = etoilesDe(gareId), best = (getProgress()[gareId] || {}).bestDelay;
  const fin = ch && ch.gares[ch.gares.length - 1] === gareId;
  return `<div class="c-fiche">
    <div class="cf-ou">${ch ? ch.nom : ""} · gare ${rang} sur ${total}${fin ? " · terminus" : ""}</div>
    <div class="cf-nom">${villeDe(gareId)}</div>
    <div class="cf-ligne">
      <span class="cf-tag">${quais} quais</span>
      <span class="cf-tag">${dirs} directions</span>
      ${pipsHTML(d)}
    </div>
    ${st ? `<div class="cf-score">${"★".repeat(st)}${best != null ? ` · record ${best} min` : ""}</div>` : ""}
  </div>`;
}

// ------------------------------------------------------------------
// LA BULLE DU RÉSULTAT — sous la gare qu'on vient de tenir.
// ------------------------------------------------------------------
function bilanHTML() {
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
  return `<div class="${cl}" role="status">
    <div class="cb-gare">${villeDe(b.gare)}</div>
    <div class="cb-etoiles">${etoiles}</div>${retard}${rec}${boutonsHTML()}</div>`;
}

const FLECHE = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" ' +
  'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
  '<path d="M5 12h13M12 6l6 6-6 6"/></svg>';
const BOUCLE = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" ' +
  'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
  '<path d="M20 11.5A8 8 0 1 1 17.4 6L20 8.5"/><path d="M20 4v5h-5"/></svg>';

// LES DEUX ISSUES, CÔTE À CÔTE ET JAMAIS L'UNE À LA PLACE DE L'AUTRE.
// Réussite : Continuer et Rejouer. Échec : Réessayer — gratuit, immédiat, sans
// limite — et Payer le passage, qui coûte des crédits et ne donne pas d'étoile.
function boutonsHTML() {
  const b = CARTE.bilan, gc = CARTE.prochaine;
  if (!b) return "";
  if (!b.win) {
    const prix = prixDePassage(b.gare), solde = soldeCredits(), assez = solde >= prix;
    const manque = prix - solde;
    return `<div class="cb-actions">` +
      `<button class="c-suite cb-suite" data-gare="${b.gare}">Réessayer${BOUCLE}</button>` +
      `<button class="c-suite cb-suite cb-payer" data-payer="${b.gare}"${assez ? "" : " disabled"}>` +
        `Passer · ◆ ${prix}</button></div>` +
      (assez ? "" : `<div class="cb-manque">Il te manque ${manque} crédit${manque > 1 ? "s" : ""} — ` +
        `rejoue une gare déjà faite pour les gagner.</div>`);
  }
  return `<div class="cb-actions">` +
    (gc ? `<button class="c-suite cb-suite cb-continuer" data-gare="${gc}">Continuer${FLECHE}</button>` : "") +
    `<button class="c-suite cb-suite cb-rejouer" data-gare="${b.gare}">Rejouer${BOUCLE}</button></div>`;
}

// ------------------------------------------------------------------
// LA FÊTE DE FIN DE CHAPITRE — et le nom du suivant, annoncé.
// ------------------------------------------------------------------
// C'est ce qui manquait le plus au test de jeu : savoir où l'on va. Le
// chapitre se ferme, son rang s'affiche, et le suivant se nomme.
function feteHTML() {
  const f = CARTE.fete;
  if (!f) return "";
  const ch = f.ch, suivant = f.suivant, rang = rangDeChapitre(ch);
  const zone = typeof zoneById === "function" ? zoneById(ch.zone) : null;
  return `<div class="c-fete" role="status">
    <div class="cf-quoi">Chapitre terminé</div>
    <div class="cf-titre">${ch.nom}</div>
    ${rang ? `<div class="cf-rang r-${rang.id}">${rang.nom}</div>` : ""}
    <div class="cf-gares">${ch.gares.length} gares · ${ch.gares.filter(estFaite).length} faites</div>
    ${f.zoneFinie && zone ? `<div class="cf-zone">${zone.nom} — région traversée</div>` : ""}
    ${suivant ? `<div class="cf-suivant">La suite : <b>${suivant.nom}</b></div>
      <button class="c-suite cb-suite cb-continuer" data-gare="${CARTE.prochaine || ""}">En route${FLECHE}</button>`
      : `<div class="cf-suivant">Le ruban s'arrête ici — pour le moment.</div>`}
  </div>`;
}

// ------------------------------------------------------------------
// LES COMPTEURS.
// ------------------------------------------------------------------
function bourseHTML() {
  if (typeof gradeOf !== "function" || typeof etoilesTotal !== "function") return "";
  const n = etoilesTotal(), g = gradeOf(n);
  const s = typeof getSerie === "function" ? getSerie() : { n: 0 };
  const cr = typeof soldeCredits === "function" ? soldeCredits() : null;
  return `<div class="c-compteurs">` +
    (s.n >= 2 ? `<span class="c-serie" title="${s.n} services d'affilée sous dix minutes">» ${s.n}</span>` : "") +
    `<span class="c-grade" title="${g.nom}"><span class="g-nom">${g.nom}</span>` +
      `<span class="g-jauge"><i style="width:${Math.round(g.part * 100)}%"></i></span></span>` +
    (cr === null ? "" : `<span class="c-credits" title="crédits">◆ ${cr}</span>`) +
    `<span class="c-etoiles">★ ${n}</span></div>`;
}

// ------------------------------------------------------------------
// LA VUE, ET LE RENDU.
// ------------------------------------------------------------------
function enTeteHTML() {
  const gc = CARTE.prochaine;
  const ch = chapitreDeGare(gc) || chapitreAt(Math.min(positionCourante(), longueurDuRuban() - 1));
  const zone = ch && typeof zoneById === "function" ? zoneById(ch.zone) : null;
  const rang = ch ? rangDeChapitre(ch) : null;
  const faits = ch ? ch.gares.filter(estFaite).length : 0;
  // Le bouton de dézoom dit OÙ L'ON VA, pas « retour » : gare → chapitre →
  // carte. Au dernier cran il porte le nom de la carte.
  const crans = { gare: ["chapitre", ch ? ch.nom : "Le chapitre"],
                  chapitre: ["carte", zone ? zone.nom : nomDeCarte()],
                  carte: ["gare", "La gare en cours"] };
  const [vers, libelle] = crans[CARTE.vue] || crans.gare;
  return `<div class="c-tete">
    <button class="c-zoom" data-vue="${vers}" title="Changer d'échelle">
      <span class="cz-ic">${CARTE.vue === "carte" ? "⊕" : "⊖"}</span>${libelle}</button>
    <div class="c-titre">
      <span class="c-nom">${ch ? ch.nom : nomDeCarte()}</span>
      ${rang ? `<span class="c-rang r-${rang.id}">${rang.nom}</span>`
             : ch ? `<span class="c-avance">${faits} / ${ch.gares.length}</span>` : ""}
    </div>
    ${bourseHTML()}
  </div>`;
}

function vueRuban() {
  const gc = gareCourante();
  CARTE.prochaine = gc;
  const ch = chapitreDeGare(gc) || chapitreAt(Math.min(positionCourante(), longueurDuRuban() - 1));
  if (!ch) return `<div class="c-tete"><div class="c-titre">Aucun chapitre n'est encore écrit</div></div>`;

  // Le saut se montre AVANT le chapitre qu'il ouvre : c'est une transition,
  // et elle a le droit d'être lue.
  const saut = ch.saut && ch.gares.indexOf(gc) === 0
    ? `<div class="c-saut"><b>${ch.saut.mode}</b>${ch.saut.texte}</div>` : "";

  // L'APPEL — un seul bouton, et il nomme la gare. Rien d'autre à décider.
  let appel = "";
  if (!CARTE.bilan && !CARTE.fete) {
    if (gc) appel = `<button class="c-suite c-appel" data-gare="${gc}">` +
      `<span class="ca-quoi">Continuer</span><span class="ca-ou">${villeDe(gc)}</span>${FLECHE}</button>`;
    else if (auBoutDeLEcrit())
      appel = `<div class="c-avenir">La suite du ruban n'est pas encore écrite.</div>`;
    else appel = `<div class="c-avenir">Le ruban est terminé. Reste à le dorer.</div>`;
  }

  return enTeteHTML() + saut + `
    <svg class="c-graphe c-ruban" viewBox="0 0 ${CADRE_L} ${CADRE_H}" preserveAspectRatio="xMidYMid meet">
      <g class="monde">${fondHTML()}${railHTML()}${garesHTML()}</g>
    </svg>
    <div class="c-panneau">
      ${CARTE.fete ? feteHTML() : CARTE.bilan ? bilanHTML() : (gc ? cartoucheHTML(gc) : "")}
      ${appel}
    </div>`;
}

function renderCarte() {
  const hote = document.getElementById("hub-map");
  if (!hote) return;
  CARTE.hote = hote;
  hote.className = "carte v-ruban n-" + CARTE.vue;
  hote.innerHTML = vueRuban();
  CARTE.etoiles = hote.querySelector(".c-etoiles");
  poserCamera();
  // LES GARES SE REDESSINENT AU BON ZOOM. Leur taille dépend de k, et k ne se
  // connaît qu'une fois le SVG mesuré : on refait donc ce seul calque après
  // la caméra. Le fond et le rail, eux, se mettent à l'échelle en CSS.
  const gs = hote.querySelector(".c-ruban .gares");
  if (gs) gs.outerHTML = garesHTML();
  hote.onclick = ev => {
    const vue = ev.target.closest("[data-vue]");
    if (vue) { CARTE.vue = vue.dataset.vue; renderCarte(); return; }
    const pay = ev.target.closest("[data-payer]");
    if (pay && !pay.disabled) { passerLaGare(pay.dataset.payer); return; }
    const g = ev.target.closest("[data-gare]");
    if (g && g.dataset.gare) { jouerGare(g.dataset.gare); return; }
  };
  hote.onkeydown = ev => {
    if (ev.key !== "Enter" && ev.key !== " ") return;
    const g = ev.target.closest("[data-gare]");
    if (g && g.dataset.gare) { ev.preventDefault(); jouerGare(g.dataset.gare); }
  };
}
function renderHub() { renderCarte(); }

// ------------------------------------------------------------------
// LE VOYAGE — la caméra glisse le long du rail.
// ------------------------------------------------------------------
// Le relevé désigne une gare par son nom ; la carte la marque d'un halo. Entre
// les deux, le joueur devrait faire lui-même le lien entre un mot et un point.
// La caméra le fait à sa place : le trajet EST la phrase. Un SAUT dure plus
// longtemps — c'est ce qui le distingue d'un rail continu.
function poserCamera() {
  const svg = CARTE.hote && CARTE.hote.querySelector(".c-graphe");
  const monde = svg && svg.querySelector(".monde");
  if (!svg || !monde) { CARTE.camAvant = null; return; }
  const c = cameraVoulue();
  CARTE.cam = c;
  svg.style.setProperty("--k", c.k.toFixed(3));
  const t = `translate(${(CADRE_L / 2 - c.k * c.x).toFixed(2)}px, ${(CADRE_H / 2 - c.k * c.y).toFixed(2)}px) scale(${c.k.toFixed(3)})`;
  // Le zoom SE JOUE, il ne se pose pas : le SVG est refait à chaque rendu, donc
  // le monde repart de sa transformation d'avant et reçoit la nouvelle — c'est
  // le CSS qui fait le trajet.
  const lent = !!CARTE.voyageSaut;
  monde.style.transitionDuration = lent ? "1.5s" : "";
  if (CARTE.camAvant && CARTE.camAvant !== t) {
    monde.style.transform = CARTE.camAvant;
    monde.getBoundingClientRect();
  }
  monde.style.transform = t;
  CARTE.camAvant = t;
  CARTE.voyage = null; CARTE.voyageSaut = false;
}

// ------------------------------------------------------------------
// LES GESTES.
// ------------------------------------------------------------------
// Un seul geste sur une gare : la jouer. Sur un ruban il n'y a rien à ouvrir —
// une gare est atteinte ou elle ne l'est pas, et elle n'est alors pas cliquable.
function jouerGare(gareId) {
  const i = CATALOG.findIndex(c => c.id === gareId);
  if (i < 0 || !estTenue(gareId)) { renderCarte(); return; }
  // On quitte la fête de chapitre : la caméra redescend sur la gare. Sans ça,
  // le chapitre suivant se jouait entièrement vu de haut, parce que la fête
  // avait pris du recul et que plus rien ne le rendait.
  if (CARTE.fete) { CARTE.fete = null; CARTE.vue = "gare"; }
  startStation(i);
}
// PASSER EN PAYANT (§4 ter). La gare reste à zéro étoile — ni jauge, ni rang,
// ni médaille — et se rejoue quand on veut : la gagner plus tard rend la mise.
function passerLaGare(gareId) {
  const prix = prixDePassage(gareId);
  if (soldeCredits() < prix || !payerPassage(gareId)) return;
  CARTE.bilan = null;
  finDeGare(gareId);
}

// ------------------------------------------------------------------
// CE QUI SE PASSE QUAND UNE GARE EST FRANCHIE.
// ------------------------------------------------------------------
// Appelé par le relevé de fin (js/game.js) et par le passage payé. Décide s'il
// y a une fête de chapitre à poser, puis fait glisser la caméra.
function finDeGare(gareId) {
  const ch = chapitreDeGare(gareId);
  const gc = gareCourante();
  const nouveauCh = chapitreDeGare(gc);
  CARTE.prochaine = gc;
  // Le chapitre vient de se fermer : on le fête, et l'on annonce le suivant.
  if (ch && chapitreTermine(ch) && nouveauCh !== ch) {
    const chs = chapitresDuRuban();
    const zone = ch.zone;
    CARTE.fete = {
      ch, suivant: chs[ch.rang + 1] || null,
      zoneFinie: chs.filter(c => c.zone === zone).every(chapitreTermine)
    };
    CARTE.bilan = null;
    CARTE.vue = "chapitre";       // on prend du recul pour voir ce qu'on a fait
  } else {
    CARTE.voyageSaut = !!(nouveauCh && nouveauCh !== ch && nouveauCh.saut);
  }
  renderCarte();
}
