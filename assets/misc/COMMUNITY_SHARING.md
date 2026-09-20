# Community Sharing & Promotion Guide

This guide outlines community outreach ideas and channels to promote your custom Fedora RPM repository and help other developers install Google Antigravity IDE on Fedora.

---

## 1. Post on the Fedora Discussion Forum

The official **[Fedora Discussion](https://discussion.fedoraproject.org/)** board is the hub for Fedora developers and contributors.

* **Target Category**: *Development* or *Desktop*.
* **Topic Outline**:
  - Introduce the package: a lightweight `noarch` wrapper for Google Antigravity IDE.
  - Explain the problem solved: solves dependencies and enables simple, automated user-space installs.
  - Provide DNF commands to add the repo and install.
  - Link to the GitHub repository for feedback.

---

## 2. Share on the Fedora Subreddit (`r/Fedora`)

Reddit has a large and active developer base running Fedora Workstation.

* **Target Subreddit**: [reddit.com/r/Fedora](https://www.reddit.com/r/Fedora/)
* **Formatting**: Keep the post short and direct.
  - **Title Idea**: *Automated Google Antigravity IDE installer for Fedora (custom YUM repo)*
  - **Body**: Show the bootstrap command:
    ```bash
    sudo dnf install https://raw.githubusercontent.com/steve-rock-wheelhouser/wheelhouserllc-repo/main/fedora/44/x86_64/steve-rock-wheelhouser-release-1.0-3.fc44.noarch.rpm
    sudo dnf install antigravity-ide
    ```

---

## 3. GitHub README Badges

Add a badge at the top of your `steve-rock-wheelhouser/antigravity-ide` repository's `README.md` to guide users:

* **Markdown Code**:
  ```markdown
  [![RPM Repo](https://img.shields.io/badge/Wheelhouser%20LLC-DNF%20Repo-294172?style=flat&logo=redhat&logoColor=white)](https://github.com/steve-rock-wheelhouser/wheelhouserllc-repo)
  ```
* This renders a clean badge linking directly to your custom repository instructions.

---

## 4. Developer Blogging & SEO

Publish a short article on developer blogging platforms like **Dev.to**, **Medium**, or **Hashnode** to capture search engine traffic.

* **Target Title**: *"How to Install Google Antigravity IDE on Fedora Linux"*
* **Why it works**: Developers looking for this package will search Google. A blog post with clear steps and code blocks will index quickly and rank high in searches.

---

## 5. Curated "Awesome" Lists

Submit your package to community lists tracking Fedora and Linux developer resources:

* **Link**: [Awesome Fedora Project](https://github.com/luya/awesome-fedora)
* **Action**: Open a Pull Request adding `antigravity-ide` under the *Developer Tools* or *Third Party Repositories* section.
