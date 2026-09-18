# Godot canvas stroke construction

presentation/northstar/stroke_mesh.gd adapts the small positive-width, open-path
antialiased stroke construction from Godot's renderer_canvas_cull.cpp:
https://github.com/godotengine/godot/blob/4.7-stable/servers/rendering/renderer_canvas_cull.cpp

Original upstream-source archive fingerprint (the original evidence archive is
not part of this public test slice). SHA256: 8D4F85652D69A3AEC8378A391F5D5CFF5F8AEB795243BEDD56DFF5C79F5D88A7.
This is a narrow presentation adapter, not a replacement for Godot's general path API.

Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
