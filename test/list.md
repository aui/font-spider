# 测试列表

目前测试用例覆盖率还有待提高，这个列表作为备忘

## font 的声明方式

1. `font-family: webfont, Arial`
2. `font-family: "webfont", Arial`
3. `font: 16px webfont, Arial`
4. `font: 16px "webfont", Arial`
5. `font-family: inherit`
6. `font-family: "inherit"`
7. 无声明：由父元素继承
8. 关键字：serif | sans-serif | monospace | cursive | fantasy | inherit

## 选择器

1. `.selector`
2. `.selector, .selector2`
3. `.selector:hover span`
4. `.selector::after`
5. `.selector:after`
6. `.selector:hover ::after`
7. `::after`
8. `@media (max-width: 768px) {.selector{}}`

## content 值

1. `content: "string"`
2. `content: attr(value)`
3. `content: "string" attr(value) "string"`

## 权重

1. 选择器与选择器的优先级
2. `font: 16px Arial!important;font-family:webfont`

## 样式声明方式

1. `<link>`
2. `<style>`
3. `@import`
4. `style=""`

## 大小写

1. `::AFTER, ::BFTER {FONT-FAMILY: webfont}`

