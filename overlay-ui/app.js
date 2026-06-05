const consul = document.querySelector(".consul");
const askForm = document.querySelector("#askForm");
const questionInput = document.querySelector("#questionInput");
const questionText = document.querySelector("#questionText");
const answerBody = document.querySelector("#answerBody");
const collapseButton = document.querySelector("#collapseButton");
const profileButtons = document.querySelectorAll("[data-profile]");

const profile = { ...window.MockConsul.profileDefaults };
let collapseTimer = 0;

askForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const question = questionInput.value.trim() || "为什么我的科技落后？";
  const answer = window.MockConsul.analyze(question, profile);

  questionText.textContent = answer.question;
  answerBody.innerHTML = answer.html;
  consul.dataset.state = "expanded";
  questionInput.value = "";
  questionInput.placeholder = answer.question;

  scheduleCollapse();
});

collapseButton.addEventListener("click", collapseAnswer);

profileButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const key = button.dataset.profile;
    const value = button.dataset.value;
    profile[key] = value;

    document
      .querySelectorAll(`[data-profile="${key}"]`)
      .forEach((candidate) => candidate.classList.toggle("is-active", candidate === button));

    if (consul.dataset.state === "expanded") {
      const activeQuestion = questionText.textContent || questionInput.placeholder;
      const answer = window.MockConsul.analyze(activeQuestion, profile);
      answerBody.innerHTML = answer.html;
      scheduleCollapse();
    }
  });
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    collapseAnswer();
  }
});

function scheduleCollapse() {
  window.clearTimeout(collapseTimer);
  collapseTimer = window.setTimeout(collapseAnswer, profile.autoCollapseSeconds * 1000);
}

function collapseAnswer() {
  window.clearTimeout(collapseTimer);
  consul.dataset.state = "idle";
  questionInput.placeholder = "Ask anything...";
}
