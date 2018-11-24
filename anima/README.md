# anima
my tools for making videos with opengl

anima folder should be in lua folder and then

```lua
require"anima"
local GL = GLcanvas{H=800,aspect=1.5}

function GL.init()
  --init gl stuff here
end

function GL.draw(t,w,h)
  --do gl work here
end

GL:start()
```
