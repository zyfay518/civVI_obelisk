window.MockConsul = (() => {
  const sampleState = {
    turn: 82,
    era: "Classical",
    player: {
      civilization: "Kongo",
      sciencePerTurn: 31,
      cityCount: 5,
      totalPopulation: 22,
      campusCount: 1,
      libraryCount: 0
    },
    knownContext: {
      knownPlayerAverageScience: 47,
      estimatedTechsBehind: 4
    }
  };

  const profileDefaults = {
    mode: "rosetta",
    answerLength: "standard",
    adviceLevel: "soft_suggest",
    language: "zh-CN",
    autoCollapseSeconds: 8
  };

  function analyze(question, profile) {
    const active = { ...profileDefaults, ...profile };
    const q = question.trim() || "为什么我的科技落后？";
    const state = sampleState;
    const scienceGap = state.knownContext.knownPlayerAverageScience - state.player.sciencePerTurn;

    if (active.mode === "antikythera") {
      return antikythera(q, active, state, scienceGap);
    }

    if (active.mode === "oracle") {
      return oracle(q, active, state, scienceGap);
    }

    return rosetta(q, active, state, scienceGap);
  }

  function rosetta(question, profile, state, scienceGap) {
    const reasons = [
      "学院数量偏少，5 座城市里当前只有 1 个学院。",
      "图书馆数量为 0，学院还没有把基础科研放大。",
      "总人口 22，支撑的基础科研还不够厚。"
    ];

    return buildAnswer({
      question,
      conclusion: `你的科技偏慢，主要不是单个城市的问题，而是科研基础还没有铺开。`,
      reasons,
      evidence: [`当前科研 ${state.player.sciencePerTurn}/回合，已知玩家均值约 ${state.knownContext.knownPlayerAverageScience}/回合，差距 ${scienceGap}/回合。`],
      whereToCheck: "可以先看城市面板里的学院区域、图书馆，以及每座城市人口。",
      profile
    });
  }

  function oracle(question, profile, state, scienceGap) {
    const reasons = [
      "第一影响项是学院覆盖率：5 城 1 学院会让科研增长滞后。",
      "第二影响项是建筑断层：没有图书馆时，学院收益还没进入稳定期。",
      "第三影响项是人口规模：22 总人口会限制基础科研和专家承载。"
    ];

    return buildAnswer({
      question,
      conclusion: `判断：你的科技落后更像是基础设施滞后，而不是短期政策选择失误。`,
      reasons,
      evidence: [
        `科研 ${state.player.sciencePerTurn}/回合，已知均值 ${state.knownContext.knownPlayerAverageScience}/回合。`,
        `估计落后约 ${state.knownContext.estimatedTechsBehind} 个科技节奏。`
      ],
      whereToCheck: "优先检查学院相邻加成、图书馆缺口、人口最高城市的建造队列。",
      profile
    });
  }

  function antikythera(question, profile, state, scienceGap) {
    const reasons = [
      `Science gap = ${state.knownContext.knownPlayerAverageScience} - ${state.player.sciencePerTurn} = ${scienceGap}/turn。`,
      `Campus coverage = ${state.player.campusCount}/${state.player.cityCount} = ${(state.player.campusCount / state.player.cityCount * 100).toFixed(0)}%。`,
      `Library multiplier is absent: library_count = ${state.player.libraryCount}。`
    ];

    return buildAnswer({
      question,
      conclusion: `结论：当前科研短板来自低学院覆盖率和缺少早期科研建筑。`,
      reasons,
      evidence: [
        `Population baseline = ${state.player.totalPopulation} total population。`,
        `Estimated tech lag = ${state.knownContext.estimatedTechsBehind}。`
      ],
      whereToCheck: "区分事实与推断：事实是科研差距和建筑缺口；推断是学院覆盖率正在拖慢恢复速度。",
      profile
    });
  }

  function buildAnswer(parts) {
    const blocks = [`<p><strong>${escapeHtml(parts.conclusion)}</strong></p>`];
    const reasonLimit = parts.profile.answerLength === "short" ? 2 : 3;

    blocks.push(renderList(parts.reasons.slice(0, reasonLimit)));

    if (parts.profile.answerLength !== "short") {
      blocks.push(`<p>${escapeHtml(parts.evidence.join(" "))}</p>`);
    }

    if (parts.profile.answerLength === "expanded") {
      blocks.push(renderMetrics());
    }

    if (parts.profile.adviceLevel !== "explain_only") {
      const prefix = parts.profile.adviceLevel === "strategic_advice" ? "可选方向：" : "可先观察：";
      blocks.push(`<p>${prefix}${escapeHtml(parts.whereToCheck)}</p>`);
    }

    return {
      question: parts.question,
      html: blocks.join("")
    };
  }

  function renderList(items) {
    return `<ul>${items.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>`;
  }

  function renderMetrics() {
    return [
      `<div class="metric-row" aria-label="Key metrics">`,
      `<span class="metric">Science: 31/turn</span>`,
      `<span class="metric">Known avg: 47/turn</span>`,
      `<span class="metric">Campuses: 1/5</span>`,
      `<span class="metric">Libraries: 0</span>`,
      `</div>`
    ].join("");
  }

  function escapeHtml(value) {
    return value
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  return {
    analyze,
    profileDefaults
  };
})();
