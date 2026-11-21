window.drawArtwork = function (canvas, strokes) {
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';

  for (const stroke of Array.isArray(strokes) ? strokes : []) {
    const points = stroke.points;
    if (!Array.isArray(points) || points.length < 2) continue;
    ctx.beginPath();
    ctx.strokeStyle = stroke.color;
    ctx.fillStyle = stroke.color;
    ctx.lineWidth = stroke.width;
    if (points.length === 2) {
      ctx.arc(points[0], points[1], stroke.width / 2, 0, Math.PI * 2);
      ctx.fill();
      continue;
    }
    ctx.moveTo(points[0], points[1]);
    for (let i = 2; i < points.length; i += 2) ctx.lineTo(points[i], points[i + 1]);
    ctx.stroke();
  }
};
