# 向日葵闹钟

别人做闹钟，是为了把你从被窝里拽起来。向日葵闹钟把这件事反过来：推迟闹铃、做完一件提醒，都会变成肥料。拖到花上，它就再长高一截。生命是用来享受的，不是用来被闹铃吵醒的。

面向 iPhone，系统闹钟走 iOS 26 的 AlarmKit。到点会响我们自己的铃，锁屏和灵动岛上可以推迟 9 分钟。语言跟着手机，也可以在系统设置里改成中文或英文。

<p>
<img src="docs/flower.png" width="180" alt="看花：向日葵">
<img src="docs/orchid.png" width="180" alt="看花：兰花">
<img src="docs/pots.png" width="180" alt="花和盆">
<img src="docs/alarm.png" width="180" alt="闹钟">
<img src="docs/timer.png" width="180" alt="计时">
</p>

## 看花

底部第一个图标。一株花站在盆里，可以左右转、近中远三档缩放。现在能养向日葵和兰花。

- **浇水**：拖水壶到花上。三天不浇会蔫，再久更蔫；浇了就重新抬起头。兰花枯萎只低头，花瓣还是原来的颜色。
- **施肥**：右边那袋便便。推迟任意一只闹铃，或把任务提醒点「停止」做完，都会进一包。拖到花上，它长高一截。没肥料时点一下，会飘过「推迟闹铃或完成任务才能拿到肥料」。
- **日期**：可以回看今天和过去 6 天。每一天的高度只属于那一天。

## 花和盆

底部花瓶。上面一排选花，下面一排选盆，滑到中间的就是现在这盆。

花：向日葵、兰花。盆：陶盆、白瓷、彩釉盆、高筒盆、方盆。

## 闹钟

底部钟表。周一到周日各自过自己的日子。自带睡觉（起床 / 睡觉），点右上角 `+` 可以加自己的提醒，比如接娃、吃药，还可以给某一天加上结束时间。

长按标签能暂停或删掉。到点走系统闹钟：锁屏、灵动岛都能停或推迟。推迟 9 分钟，肥料进账；任务响着的时候点停止，也算完成，同样给肥料。

第一次打开会有教程：先圈加号，再圈星期和时间，然后是长按标签、长按某一天。点一下进下一步。

电脑上没有真闹钟。编辑器里那颗「记一次推迟」只是彩排。

## 计时

底部 TIMER。煮面、番茄钟、休息，点一下就弹出确认，开始倒计时；也可以点「自定」起名字、选时长，创建之后立刻开始。一次只走一个。点取消就停，自己加的那颗按钮还留在下面，长按可以删。

到点发一条提醒，不走系统闹钟。计时中锁屏上有横幅，灵动岛上也有，可以取消本次计时。锁屏横幅和灵动岛是同一条 Live Activity，滑掉横幅，岛也会一起收起来。

第一次打开会说明三个模板、长按删除，以及怎么自己定时长。

## 行程

底部日历。要做的事按本周、下周、下下周、更远往下排，颜色一层比一层深。最底下是已完成，书签写成「已完成🐳」，深海蓝。

本周从今天开始。今天若是周三，周一和周二不再占一行。下周仍然从周一排到周日。今天的条目不看现在几点：早上已经过了的起床还在今天；今天响过的一次性提醒也留在今天，标着已完成。昨天和更早的才沉到最底下，长按只能删，八秒内可以撤销。

蓝色是每周都会响的。起床和睡觉合成一行，在闹钟页加的每周提醒也是蓝的，加完会出现在行程里。长按蓝的，只能去闹钟页改时间，或回到闹钟页删掉那一项。这些固定每周提醒不会出现在更远，那里写着：你的「固定每周提醒」不会在此处显示的哦。

黄色是只响一次。点 `+ 添加`，可以放在本周、下周、下下周，也可以自选更远的日期。长按可以改日期和时间，也可以删。改到明年，它会出现在更远；改回下周，它就回到下周；删掉之后那一行消失。

一条都没有的时候，中间只剩一行灰字：白茫茫大雪真干净。本周、下周这些分段都不出现。

第一次打开会分开讲蓝色和黄色、怎么去改闹钟、怎么添加、怎么删除。

## 声音

森林一直在响。点按钮是水底一声。花长高另有一段。闹铃是 `sunflower.caf`。

## 自己改

花和盆是 Blender 里做好的 `.glb`，在 `assets/`。界面在 `scenes/`，颜色在 `theme/ui.tres`，文案在 `locale/ui.csv`，都可以在 Godot 里直接改。灯光、相机、花盆、按钮都放在场景里，不要用代码再 `new()` 拼进去。

## 测试

在仓库根目录运行：

```
python3 tests/check.py
```

需要本机的 Godot（`/Applications/Godot.app`），并且 Jwu 16 连着、状态是 available。脚本会先把手机上的闹钟数据拷下来，在一份临时工程里把界面走一遍。临时工程的名字是 Sunflower Alarm Test，不会写进真正的存档。跑完把手机和电脑上的数据放回去，然后打开 `test-report/index.html`。缺 gdUnit4 时会自己下载 6.2.2。

编辑器里如果正开着游戏，电脑上的闹钟存档会按开跑前的样子放回去。

下面是最近一次跑出来的过程。每一组从左到右，是一个状态到下一个状态。

### 添加每周提醒

从左到右：写下浇花，新标签还没有时间，选上午 9:30，七天都要提醒，浇花定在上午 9:30，行程里出现了浇花，长按可以去改这个闹钟，把这一天改成下午 4:45，这一天已经是 16:45，行程里这一天变成 16:45，长按标签可以删除，确认删掉浇花，删掉之后行程里没有浇花了。

<p>
<img src="docs/shots/001.png" width="150" alt="写下浇花">
<img src="docs/shots/002.png" width="150" alt="新标签还没有时间">
<img src="docs/shots/003.png" width="150" alt="选上午 9:30">
<img src="docs/shots/004.png" width="150" alt="七天都要提醒">
<img src="docs/shots/005.png" width="150" alt="浇花定在上午 9:30">
<img src="docs/shots/006.png" width="150" alt="行程里出现了浇花">
<img src="docs/shots/007.png" width="150" alt="长按可以去改这个闹钟">
<img src="docs/shots/008.png" width="150" alt="把这一天改成下午 4:45">
<img src="docs/shots/009.png" width="150" alt="这一天已经是 16:45">
<img src="docs/shots/010.png" width="150" alt="行程里这一天变成 16:45">
<img src="docs/shots/011.png" width="150" alt="长按标签可以删除">
<img src="docs/shots/012.png" width="150" alt="确认删掉浇花">
<img src="docs/shots/013.png" width="150" alt="删掉之后行程里没有浇花了">
</p>

### 底栏切换

从左到右：先在看花，行程，再点行程，回到看花，花盆，定时，计时。

<p>
<img src="docs/shots/014.png" width="150" alt="先在看花">
<img src="docs/shots/015.png" width="150" alt="行程">
<img src="docs/shots/016.png" width="150" alt="再点行程，回到看花">
<img src="docs/shots/017.png" width="150" alt="花盆">
<img src="docs/shots/018.png" width="150" alt="定时">
<img src="docs/shots/019.png" width="150" alt="计时">
</p>

### 计时

从左到右：还没开始，写上泡茶，定 8 分钟，泡茶开始倒计时，停掉了，泡茶还留在下面。

<p>
<img src="docs/shots/020.png" width="150" alt="还没开始">
<img src="docs/shots/021.png" width="150" alt="写上泡茶，定 8 分钟">
<img src="docs/shots/022.png" width="150" alt="泡茶开始倒计时">
<img src="docs/shots/023.png" width="150" alt="停掉了，泡茶还留在下面">
</p>

### 本周从今天开始

从左到右：本周只留下今天和后面的日子，下周仍然从周一排到周日。

<p>
<img src="docs/shots/024.png" width="150" alt="本周只留下今天和后面的日子">
<img src="docs/shots/025.png" width="150" alt="下周仍然从周一排到周日">
</p>

### 今天已经过去的也列出

从左到右：今天早上的这条还在今天。

<p>
<img src="docs/shots/026.png" width="150" alt="今天早上的这条还在今天">
</p>

### 什么也没有

从左到右：只剩白茫茫大雪真干净。

<p>
<img src="docs/shots/027.png" width="150" alt="只剩白茫茫大雪真干净">
</p>

### 已完成可以删掉再撤销

从左到右：已完成里出现这条旧事，长按只有删除，删掉了，可以撤销，撤销之后它回来了。

<p>
<img src="docs/shots/028.png" width="150" alt="已完成里出现这条旧事">
<img src="docs/shots/029.png" width="150" alt="长按只有删除">
<img src="docs/shots/030.png" width="150" alt="删掉了，可以撤销">
<img src="docs/shots/031.png" width="150" alt="撤销之后它回来了">
</p>

### 还没到的提醒

从左到右：明天的这条还在行程里，长按可以编辑，也可以删除。

<p>
<img src="docs/shots/032.png" width="150" alt="明天的这条还在行程里">
<img src="docs/shots/033.png" width="150" alt="长按可以编辑，也可以删除">
</p>

### 每周重复只看详情

从左到右：今天的起床和睡觉，长按只有详情。

<p>
<img src="docs/shots/034.png" width="150" alt="今天的起床和睡觉">
<img src="docs/shots/035.png" width="150" alt="长按只有详情">
</p>

### 四个一次性提醒

从左到右：选本周的一天，名叫本周一事，本周一事的时间，确认这条提醒，本周一事出现在本周，选下周的一天，名叫下周一事，下周一事的时间，确认这条提醒，下周一事出现在下周，选下下周的一天，名叫下下周一事，下下周一事的时间，确认这条提醒，下下周一事出现在下下周，自选 2027-03-01，更远一事的时间，确认这条提醒，更远一事出现在更远，长按本周这一条，自选 2027-08-08，改到明年 8 月 8 日，确认这条提醒，它跑到了更远，改回下周，时间还是晚上 11 点，确认这条提醒，又回到下周，再长按，这次删掉，本周那条不见了，另外三条还在。

<p>
<img src="docs/shots/036.png" width="150" alt="选本周的一天，名叫本周一事">
<img src="docs/shots/037.png" width="150" alt="本周一事的时间">
<img src="docs/shots/038.png" width="150" alt="确认这条提醒">
<img src="docs/shots/039.png" width="150" alt="本周一事出现在本周">
<img src="docs/shots/040.png" width="150" alt="选下周的一天，名叫下周一事">
<img src="docs/shots/041.png" width="150" alt="下周一事的时间">
<img src="docs/shots/042.png" width="150" alt="确认这条提醒">
<img src="docs/shots/043.png" width="150" alt="下周一事出现在下周">
<img src="docs/shots/044.png" width="150" alt="选下下周的一天，名叫下下周一事">
<img src="docs/shots/045.png" width="150" alt="下下周一事的时间">
<img src="docs/shots/046.png" width="150" alt="确认这条提醒">
<img src="docs/shots/047.png" width="150" alt="下下周一事出现在下下周">
<img src="docs/shots/048.png" width="150" alt="自选 2027-03-01">
<img src="docs/shots/049.png" width="150" alt="更远一事的时间">
<img src="docs/shots/050.png" width="150" alt="确认这条提醒">
<img src="docs/shots/051.png" width="150" alt="更远一事出现在更远">
<img src="docs/shots/052.png" width="150" alt="长按本周这一条">
<img src="docs/shots/053.png" width="150" alt="自选 2027-08-08">
<img src="docs/shots/054.png" width="150" alt="改到明年 8 月 8 日">
<img src="docs/shots/055.png" width="150" alt="确认这条提醒">
<img src="docs/shots/056.png" width="150" alt="它跑到了更远">
<img src="docs/shots/057.png" width="150" alt="改回下周">
<img src="docs/shots/058.png" width="150" alt="时间还是晚上 11 点">
<img src="docs/shots/059.png" width="150" alt="确认这条提醒">
<img src="docs/shots/060.png" width="150" alt="又回到下周">
<img src="docs/shots/061.png" width="150" alt="再长按，这次删掉">
<img src="docs/shots/062.png" width="150" alt="本周那条不见了，另外三条还在">
</p>

### 定时教程

从左到右：先圈住加号，星期和时间，长按上面的标签，长按左边的某一天，点完最后一步，教程收起。

<p>
<img src="docs/shots/063.png" width="150" alt="先圈住加号">
<img src="docs/shots/064.png" width="150" alt="星期和时间">
<img src="docs/shots/065.png" width="150" alt="长按上面的标签">
<img src="docs/shots/066.png" width="150" alt="长按左边的某一天">
<img src="docs/shots/067.png" width="150" alt="点完最后一步，教程收起">
</p>

### 计时教程

从左到右：点一下就开始计时，长按自己加的可以删，点加号自己定时长，点完最后一步，教程收起。

<p>
<img src="docs/shots/068.png" width="150" alt="点一下就开始计时">
<img src="docs/shots/069.png" width="150" alt="长按自己加的可以删">
<img src="docs/shots/070.png" width="150" alt="点加号自己定时长">
<img src="docs/shots/071.png" width="150" alt="点完最后一步，教程收起">
</p>

### 行程教程

从左到右：蓝的每周重复，黄的只响一次，长按蓝的可以去改闹钟，点这里加一条只响一次，长按黄的可以改，也可以删，点完最后一步，教程收起。

<p>
<img src="docs/shots/072.png" width="150" alt="蓝的每周重复，黄的只响一次">
<img src="docs/shots/073.png" width="150" alt="长按蓝的可以去改闹钟">
<img src="docs/shots/074.png" width="150" alt="点这里加一条只响一次">
<img src="docs/shots/075.png" width="150" alt="长按黄的可以改，也可以删">
<img src="docs/shots/076.png" width="150" alt="点完最后一步，教程收起">
</p>
