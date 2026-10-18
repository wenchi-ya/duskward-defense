# 原创音乐与音效

本目录声音由 `generate_audio.py` 使用 Python 标准库离线合成，不使用外部录音、商业曲目、采样库、网络服务或收费工具。游戏播放已生成的 WAV，不需要安装 Python。

- `music/hearth.wav`：48 秒，菜单与选关，柔和拨弦、笛声与轻打击乐。
- `music/border_watch.wav`：38.4 秒，前三关，较清晰的行进节拍。
- `music/last_bastion.wav`：约 35.56 秒，后三关，降低调性、增强鼓点。
- `sfx/`：操作、建造、升级、箭矢、魔法、炮击、近战、消灭、陨火、援军、波次、胜利、失败及漏怪，共 14 段。

格式为 22050 Hz、16 位、双声道 PCM。音乐尾音与短延迟回声环绕写入循环起点；运行时设置完整采样范围循环，切入时淡入。音效使用短起音和释放包络减少爆音。

复现：在项目目录运行 `python audio/generate_audio.py`，仅重建本目录 WAV。旋律与合成代码为本项目制作，未引用参考游戏的原声或音效；来源同时登记在 `licenses/sources.json`。

后续导出应将 `audio/music/*.wav`、`audio/sfx/*.wav` 原始文件包含到包内，供 `AudioStreamWAV.load_from_file()` 读取；独立导出尚未验证。
