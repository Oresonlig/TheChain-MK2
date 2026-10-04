// Visar de senaste CI-byggena: byggnummer (= appens "build N"), commit, läge.
// Bara läsning mot GitHubs publika API — skriver ingenting.
//   node tool/build_status.mjs [antal]
const n = Number(process.argv[2] ?? 5);
const res = await fetch(`https://api.github.com/repos/Oresonlig/TheChain-MK2/actions/runs?per_page=${n}`, {
  headers: { 'User-Agent': 'thechain-build-status' },
});
if (!res.ok) {
  console.error(`GitHub svarade ${res.status}`);
  process.exit(1);
}
const { workflow_runs: runs } = await res.json();
for (const r of runs) {
  const msg = (r.head_commit?.message ?? '').split('\n')[0];
  console.log(`build ${r.run_number}  ${r.head_sha.slice(0, 7)}  ${r.status}${r.conclusion ? '/' + r.conclusion : ''}  ${msg}`);
}
