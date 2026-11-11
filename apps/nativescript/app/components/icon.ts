import { Color, Property, Utils, View } from '@nativescript/core';

/**
 * Stroke-only vector icon drawn natively (CAShapeLayer on iOS, ShapeDrawable on
 * Android). Paths are the design's 24x24 SVG icons, expressed as primitive ops.
 */
type Op =
  | ['M', number, number]
  | ['L', number, number]
  | ['Q', number, number, number, number]
  | ['O', number, number, number] // full circle cx, cy, r
  | ['A', number, number, number, number, number] // arc cx, cy, r, startDeg, sweepDeg (clockwise in screen coords)
  | ['Z'];

const ICONS: Record<string, Op[]> = {
  // M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z
  home: [
    ['M', 3, 10.5],
    ['L', 12, 3],
    ['L', 21, 10.5],
    ['L', 21, 20],
    ['Q', 21, 21, 20, 21],
    ['L', 15, 21],
    ['L', 15, 15],
    ['L', 9, 15],
    ['L', 9, 21],
    ['L', 4, 21],
    ['Q', 3, 21, 3, 20],
    ['Z'],
  ],
  // circle(11,11,7) + m20 20-3.5-3.5
  search: [
    ['O', 11, 11, 7],
    ['M', 20, 20],
    ['L', 16.5, 16.5],
  ],
  // M6 7h12l-1 13H7z + M9 7a3 3 0 0 1 6 0
  cart: [
    ['M', 6, 7],
    ['L', 18, 7],
    ['L', 17, 20],
    ['L', 7, 20],
    ['Z'],
    ['M', 9, 7],
    ['A', 12, 7, 3, 180, 180],
  ],
  // m15 5-7 7 7 7
  back: [
    ['M', 15, 5],
    ['L', 8, 12],
    ['L', 15, 19],
  ],
  // M12 5v14M5 12h14
  plus: [
    ['M', 12, 5],
    ['L', 12, 19],
    ['M', 5, 12],
    ['L', 19, 12],
  ],
  // M5 12h14
  minus: [
    ['M', 5, 12],
    ['L', 19, 12],
  ],
  // circle(12,12,9) + M12 7.5v5.5 + M12 16.5h.01
  alert: [
    ['O', 12, 12, 9],
    ['M', 12, 7.5],
    ['L', 12, 13],
    ['M', 12, 16.5],
    ['L', 12.01, 16.5],
  ],
};

export class Icon extends View {
  name: string;
  stroke: number;
  iconColor: string;

  private shapeLayer: CAShapeLayer;

  createNativeView(): any {
    if (__APPLE__) {
      const view = UIView.new();
      view.userInteractionEnabled = false;
      const layer = CAShapeLayer.new();
      layer.fillColor = null;
      layer.lineCap = kCALineCapRound;
      layer.lineJoin = kCALineJoinRound;
      view.layer.addSublayer(layer);
      this.shapeLayer = layer;
      return view;
    }
    const iv = new android.widget.ImageView(this._context);
    iv.setClickable(false);
    iv.setImportantForAccessibility(android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO);
    return iv;
  }

  initNativeView(): void {
    super.initNativeView();
    this.redraw();
  }

  disposeNativeView(): void {
    this.shapeLayer = null;
    super.disposeNativeView();
  }

  onLayout(left: number, top: number, right: number, bottom: number): void {
    super.onLayout(left, top, right, bottom);
    if (__APPLE__) this.redraw();
  }

  redraw(): void {
    const ops = ICONS[this.name];
    if (!this.nativeViewProtected || !ops) return;
    const color = new Color(this.iconColor || '#1C1B19');
    const strokeWidth = this.stroke || 1.75;
    if (__APPLE__) {
      const layer = this.shapeLayer;
      const size = Utils.layout.toDeviceIndependentPixels(this.getMeasuredWidth()) || 24;
      const s = size / 24;
      const path = UIBezierPath.bezierPath();
      for (const op of ops) {
        switch (op[0]) {
          case 'M':
            path.moveToPoint(CGPointMake(op[1] * s, op[2] * s));
            break;
          case 'L':
            path.addLineToPoint(CGPointMake(op[1] * s, op[2] * s));
            break;
          case 'Q':
            path.addQuadCurveToPointControlPoint(CGPointMake(op[3] * s, op[4] * s), CGPointMake(op[1] * s, op[2] * s));
            break;
          case 'O':
            path.appendPath(UIBezierPath.bezierPathWithOvalInRect(CGRectMake((op[1] - op[3]) * s, (op[2] - op[3]) * s, op[3] * 2 * s, op[3] * 2 * s)));
            break;
          case 'A': {
            const start = (op[4] * Math.PI) / 180;
            const end = ((op[4] + op[5]) * Math.PI) / 180;
            path.addArcWithCenterRadiusStartAngleEndAngleClockwise(CGPointMake(op[1] * s, op[2] * s), op[3] * s, start, end, true);
            break;
          }
          case 'Z':
            path.closePath();
            break;
        }
      }
      layer.frame = CGRectMake(0, 0, size, size);
      layer.path = path.CGPath;
      layer.lineWidth = strokeWidth * s;
      layer.strokeColor = color.ios.CGColor;
      return;
    }
    const p = new android.graphics.Path();
    for (const op of ops) {
      switch (op[0]) {
        case 'M':
          p.moveTo(op[1], op[2]);
          break;
        case 'L':
          p.lineTo(op[1], op[2]);
          break;
        case 'Q':
          p.quadTo(op[1], op[2], op[3], op[4]);
          break;
        case 'O':
          p.addCircle(op[1], op[2], op[3], android.graphics.Path.Direction.CW);
          break;
        case 'A':
          p.arcTo(new android.graphics.RectF(op[1] - op[3], op[2] - op[3], op[1] + op[3], op[2] + op[3]), op[4], op[5], false);
          break;
        case 'Z':
          p.close();
          break;
      }
    }
    const drawable = new android.graphics.drawable.ShapeDrawable(new android.graphics.drawable.shapes.PathShape(p, 24, 24));
    const paint = drawable.getPaint();
    paint.setStyle(android.graphics.Paint.Style.STROKE);
    paint.setStrokeWidth(strokeWidth);
    paint.setStrokeCap(android.graphics.Paint.Cap.ROUND);
    paint.setStrokeJoin(android.graphics.Paint.Join.ROUND);
    paint.setAntiAlias(true);
    paint.setColor(color.android);
    const iv = this.nativeViewProtected as android.widget.ImageView;
    const px = Math.max(1, Math.round(Utils.layout.toDevicePixels(24)));
    drawable.setIntrinsicWidth(px);
    drawable.setIntrinsicHeight(px);
    iv.setScaleType(android.widget.ImageView.ScaleType.FIT_XY);
    iv.setImageDrawable(drawable);
    iv.invalidate();
  }
}

const redraw = (target: Icon) => target.redraw();
new Property<Icon, string>({ name: 'name', valueChanged: redraw }).register(Icon);
new Property<Icon, number>({ name: 'stroke', valueConverter: parseFloat, valueChanged: redraw }).register(Icon);
new Property<Icon, string>({ name: 'iconColor', valueChanged: redraw }).register(Icon);
