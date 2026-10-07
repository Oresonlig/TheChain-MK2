// Visar stegen i senaste (eller angivet) CI-bygge: vilket steg som kör/felade
// och hur länge. Bara läsning mot GitHubs publika API.
//   node tool/build_steps.mjs [byggnummer]
const want = process.argv[2] ? Number(process.argv[2]) : null;
const gh = (p) =>
  fetch(`https://api.github.com/repos/Oresonlig/TheChain-MK2/${p}`, { headers: { 'User-Agent': 'thechain-build-steps' } }).then((r) => {
    if (!r.ok) throw new Error(`GitHub svarade ${r.status}`);
    return r.json();
  });
const { workflow_runs: runs } = await gh('actions/runs?per_page=10');
const run = want ? runs.find((r) => r.run_number === want) : runs[0];
if (!run) {
  console.error('Hittar inte bygget');
  process.exit(1);
}
console.log(`build ${run.run_number}  ${run.status}${run.conclusion ? '/' + run.conclusion : ''}  ${run.html_url}`);
const { jobs } = await gh(`actions/runs/${run.id}/jobs`);
for (const j of jobs) {
  for (const s of j.steps ?? []) {
    const secs = s.started_at && s.completed_at ? Math.round((new Date(s.completed_at) - new Date(s.started_at)) / 1000) : null;
    console.log(`  ${s.status}${s.conclusion ? '/' + s.conclusion : ''}  ${s.name}${secs == null ? '' : `  (${secs}s)`}`);
  }
  // Fel/varningar som CI fäster vid koden (t.ex. analyze-fynd).
  if (j.conclusion === 'failure') {
    const notes = await gh(`check-runs/${j.id}/annotations`);
    for (const a of notes) console.log(`  ! ${a.annotation_level}  ${a.path}:${a.start_line}  ${a.message}`);
  }
}
