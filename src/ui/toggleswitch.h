#pragma once

#include <QAbstractButton>

class QPropertyAnimation;

/** 简约胶囊开关：圆角轨道 + 滑动圆钮，玫红主色，带过渡动画。 */
class ToggleSwitch final : public QAbstractButton
{
    Q_OBJECT
    Q_PROPERTY(qreal knob READ knob WRITE setKnob)

public:
    explicit ToggleSwitch(QWidget *parent = nullptr);

    QSize sizeHint() const override;
    QSize minimumSizeHint() const override { return sizeHint(); }

    qreal knob() const { return m_knob; }
    void setKnob(qreal value);

protected:
    void paintEvent(QPaintEvent *event) override;
    void checkStateSet() override;

private:
    void animateTo(bool checked);

    qreal m_knob = 0.0;
    QPropertyAnimation *m_anim = nullptr;
};
