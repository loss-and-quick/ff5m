// Font structures declaration
//
// Copyright (C) 2025, Alexander K <https://github.com/drA1ex>
//
// This file may be distributed under the terms of the GNU GPLv3 license

#pragma once

#include <cstdint>

// Font generator project can be found here: https://github.com/DrA1ex/font2bitmap-converter

// It's a extension of a format descried here:
// https://learn.adafruit.com/creating-custom-symbol-font-for-adafruit-gfx-library/creating-new-glyphs
// https://learn.adafruit.com/creating-custom-symbol-font-for-adafruit-gfx-library/advanced-topics

struct Glyph {
    uint32_t offset;

    uint8_t width;
    uint8_t height;

    int8_t advanceX;

    int8_t offsetX;
    int8_t offsetY;
};

struct Font {
    const char *name;
    uint8_t bpp;

    uint8_t *buffer;
    Glyph *glyphs;

    uint16_t codeFrom;
    uint16_t codeTo;

    int8_t advanceY;
};
