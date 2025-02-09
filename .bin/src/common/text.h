// Text drawing
//
// Copyright (C) 2025, Alexander K <https://github.com/drA1ex>
//
// This file may be distributed under the terms of the GNU GPLv3 license

#pragma once

#include "./fonts/types.h"

class TextDrawer {
    uint32_t *_screen;
    uint32_t _width;
    uint32_t _height;

    uint32_t _color = 0xffffffff;
    uint32_t _backgroundColor = 0;
    const Font *_font = nullptr;

    int32_t _positionX = 0;

    int32_t _cursorX = 0;
    int32_t _cursorY = 0;

    uint8_t _scaleX = 1;
    uint8_t _scaleY = 1;

public:
    TextDrawer(uint32_t *screen, uint32_t width, uint32_t height):
        _screen(screen), _width(width), _height(height) {}

    [[nodiscard]] const Font *font() const;

    void setFont(const Font *font);
    void setColor(uint32_t color);
    void setBackgroundColor(uint32_t color);
    void setPosition(int32_t x, int32_t y);
    void setFontScale(int32_t scaleX, int32_t scaleY);

    void print(const char *text);
    void breakLine();

private:
    void _drawChar(char symbol);

    void _setPixel(int32_t x, int32_t y, uint32_t color);
    void _fillRect(int32_t x, int32_t y, uint32_t width, uint32_t height, uint32_t color);
};
