# NoughtQ 的游戏开发笔记

由于原来的[笔记网站](https://note.noughtq.top)已经有太多笔记了，超过了 Github Pages 的容量限制，所以我将游戏开发相关的笔记迁移到这个新的仓库，并且采用 [Zensical](https://zensical.org/) 框架（Material for Mkdocs 项目原版人马开发，底层用 Rust 写的，性能更好，不过目前还是 Alpha 版本）部署。

## 工具链

由于 Zensical 目前还是 Alpha 版本，所以插件什么的还没搞好，mkdocs 那些插件在这里就没法用了。不过幸运的是，现在有了 AI 大人的帮助，移植这些插件。目前的想法是尽可能用前端代码（HTML、CSS 和 JS 三件套）来实现功能，这样应该能做到向前兼容。目前移植过来的插件有：

- [zensical-statistics-plugin](https://github.com/NoughtQ/zensical-statistics-plugin)：改编自 TonyCrane 前辈的 [mkdocs-statistics-plugin
](https://github.com/TonyCrane/mkdocs-statistics-plugin)
- ...