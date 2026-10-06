import controlP5.*;

// ============================================================
// 大砲迎撃ゲーム V1.0 (提出版)
// ============================================================

// --------------------
// 定数
// --------------------
final int SCREEN_START  = 0;
final int SCREEN_GAME   = 1;
final int SCREEN_RESULT = 2;

final int   MAX_ESCAPED      = 3;    // 逃した敵の上限
final int   SHOT_DELAY       = 45;   // 発射→着弾までのフレーム数
final int   EXPLOSION_TIME   = 20;   // 爆発演出のフレーム数
final int   SPAWN_INTERVAL   = 125;   // 敵の出現間隔
final float EXPLOSION_RADIUS = 55;   // 爆発範囲

// 座標系の基準(setupで確定。height/widthはsize()後でないと使えないため)
float dangerY;   // 大砲手前ライン
float cannonX, cannonY;

// --------------------
// 状態
// --------------------
int screen = SCREEN_START;

ControlP5 cp5;
Slider aimXSlider, aimYSlider;
controlP5.Controller[][] ui = new controlP5.Controller[3][];   // ui[画面] = その画面で表示する部品

PFont myFont;

ArrayList<Enemy> enemies = new ArrayList<Enemy>();
int score, escaped, spawnTimer;

// スライダー名と同名の変数は、ControlP5が自動で値を書き込む
float aimX = 0.5;
float aimY = 0.5;

// 発射物
boolean projectileFlying = false;
float shotX, shotY;
int shotTimer;

// 爆発(explosionTimer > 0 の間だけ表示)
float explosionX, explosionY;
int explosionTimer;


// ============================================================
// SETUP
// ============================================================
void setup() {
  size(1000, 700);
  surface.setTitle("Enemy Interception V0.1");

  dangerY = height - 220;
  cannonX = width / 2;
  cannonY = height - 130;

  myFont = createFont("Meiryo", 32);
  textFont(myFont);

  cp5 = new ControlP5(this);
  cp5.setFont(new ControlFont(myFont, 18));   // ControlP5のラベルを日本語対応に


  createUI();
  changeScreen(SCREEN_START);
}


// ============================================================
// UI
// ============================================================
void createUI() {
  Button startButton = cp5.addButton("startGame")
    .setPosition(width / 2 - 100, height * 0.65)
    .setSize(200, 60)
    .setLabel("START");

  aimXSlider = cp5.addSlider("aimX")
    .setPosition(width * 0.25, height - 110)
    .setSize((int)(width * 0.50), 30)
    .setRange(0, 1)
    .setValue(0.5)
    .setLabel("左右");

  aimYSlider = cp5.addSlider("aimY")
    .setPosition(width * 0.25, height - 65)
    .setSize((int)(width * 0.50), 30)
    .setRange(0, 1)
    .setValue(0.5)
    .setLabel("奥行");

  Button fireButton = cp5.addButton("fire")
    .setPosition(width / 2 - 80, height - 170)
    .setSize(160, 55)
    .setLabel("発射");

  Button retryButton = cp5.addButton("retryGame")
    .setPosition(width / 2 - 100, height * 0.70)
    .setSize(200, 60)
    .setLabel("もう一度");

  ui[SCREEN_START]  = new controlP5.Controller[] { startButton };
  ui[SCREEN_GAME]   = new controlP5.Controller[] { aimXSlider, aimYSlider, fireButton };
  ui[SCREEN_RESULT] = new controlP5.Controller[] { retryButton };
}

// 画面を切り替え、その画面の部品だけ表示する
void changeScreen(int next) {
  screen = next;
  for (int s = 0; s < ui.length; s++) {
    for (controlP5.Controller c : ui[s]) {
      if (s == next) c.show();
      else           c.hide();
    }
  }
}


// ============================================================
// DRAW
// ============================================================
void draw() {
  background(15, 18, 25);

  if (screen == SCREEN_START) {
    drawStartScreen();
  } else if (screen == SCREEN_GAME) {
    updateGame();
    drawGameScreen();
  } else {
    drawResultScreen();
  }
}

// 中央揃えのテキスト
void label(String s, float y, int size, int gray) {
  fill(gray);
  textSize(size);
  text(s, width / 2, y);
}


// ============================================================
// START / RESULT 画面
// ============================================================
void drawStartScreen() {
  textAlign(CENTER, CENTER);
  label("ARTILLERY INTERSEPTION",           height * 0.25, 48, 255);
  label("迫り来る敵(リンゴ)を大砲で迎撃せよ！", height * 0.38, 22, 190);
  label("2本のバーで着弾地点を調整して発射", height * 0.46, 18, 190);
  label("敵を" + MAX_ESCAPED + "体逃すとゲームオーバー", height * 0.51, 18, 190);
}

void drawResultScreen() {
  textAlign(CENTER, CENTER);
  label("GAME OVER",               height * 0.28, 52, 255);
  label("SCORE : " + score,        height * 0.43, 30, 255);
  label("もう一度プレイできます",  height * 0.52, 20, 190);
}


// ============================================================
// GAME 更新
// ============================================================
void updateGame() {
  // 敵の出現
  if (--spawnTimer <= 0) {
    enemies.add(new Enemy());
    spawnTimer = SPAWN_INTERVAL;
  }

  // 発射物 → 着弾
  if (projectileFlying && --shotTimer <= 0) {
    projectileFlying = false;
    impact();
  }

  // 爆発演出
  if (explosionTimer > 0) explosionTimer--;

  // 敵の移動と危険ライン判定(削除するので後ろから回す)
  for (int i = enemies.size() - 1; i >= 0; i--) {
    Enemy e = enemies.get(i);
    e.update();

    if (e.y > dangerY) {
      enemies.remove(i);
      if (++escaped >= MAX_ESCAPED) {
        gameOver();
        return;
      }
    }
  }
}

void impact() {
  explosionX = shotX;
  explosionY = shotY;
  explosionTimer = EXPLOSION_TIME;

  int hit = 0;
  for (int i = enemies.size() - 1; i >= 0; i--) {
    Enemy e = enemies.get(i);
    if (dist(e.x, e.y, shotX, shotY) <= EXPLOSION_RADIUS) {
      enemies.remove(i);
      hit++;
    }
  }

  score += hit * 100;
}


// ============================================================
// GAME 描画
// ============================================================
void drawGameScreen() {
  drawBattleField();
  for (Enemy e : enemies) e.display();
  drawAimPoint();
  drawShot();
  drawExplosion();
  drawCannon();
  drawGameInfo();
}

void drawBattleField() {
  noStroke();
  fill(25, 30, 42);
  rect(0, 0, width, dangerY + 30);

  // 奥行きを表すライン
  stroke(45, 55, 70);
  for (int i = 1; i < 8; i++) {
    float y = map(i, 0, 8, 40, dangerY);
    line(0, y, width, y);
  }

  // 左右の境界
  stroke(60, 70, 90);
  line(40, 0, 40, dangerY + 30);
  line(width - 40, 0, width - 40, dangerY + 30);

  // 大砲手前ライン
  stroke(255, 90, 90);
  strokeWeight(3);
  line(40, dangerY, width - 40, dangerY);
  strokeWeight(1);

  fill(255, 120, 120);
  textAlign(LEFT, CENTER);
  textSize(16);
  text("DANGER LINE", 50, dangerY - 20);
}

void drawAimPoint() {
  float x = getAimX();
  float y = getAimY();

  stroke(80, 220, 255, 100);
  line(x, y - 25, x, y + 25);
  line(x - 25, y, x + 25, y);

  noFill();
  stroke(80, 220, 255);
  ellipse(x, y, 45, 45);

  fill(80, 220, 255);
  noStroke();
  ellipse(x, y, 8, 8);
}

void drawShot() {
  if (!projectileFlying) return;

  float progress = 1.0 - (float)shotTimer / SHOT_DELAY;

  noStroke();
  fill(255, 230, 80);
  ellipse(lerp(cannonX, shotX, progress), lerp(dangerY, shotY, progress), 18, 18);
}

void drawExplosion() {
  if (explosionTimer <= 0) return;

  float progress = 1.0 - (float)explosionTimer / EXPLOSION_TIME;
  float d = EXPLOSION_RADIUS * progress * 2;

  noFill();
  stroke(255, 180, 50, 220);
  strokeWeight(4);
  ellipse(explosionX, explosionY, d, d);
  strokeWeight(1);
}

void drawCannon() {
  noStroke();

  // 土台
  fill(70, 75, 85);
  rect(cannonX - 55, cannonY + 35, 110, 35);

  // 砲身
  float angle = atan2(getAimY() - cannonY, getAimX() - cannonX);
  pushMatrix();
  translate(cannonX, cannonY);
  rotate(angle);
  fill(100, 105, 115);
  rect(0, -12, 100, 24);
  popMatrix();

  // 本体
  fill(90);
  ellipse(cannonX, cannonY, 70, 70);
}

void drawGameInfo() {
  fill(255);
  textSize(20);

  textAlign(LEFT, TOP);
  text("SCORE : " + score, 25, 20);
  text("ESCAPED : " + escaped + " / " + MAX_ESCAPED, 25, 50);

  textAlign(RIGHT, TOP);
  text("AIM", width - 25, 20);
}


// ============================================================
// 操作
// ============================================================
float getAimX() { return map(aimX, 0, 1, 60, width - 60); }
float getAimY() { return map(aimY, 0, 1, 50, dangerY - 50); }

// STARTボタン(RESULTのもう一度も同じ処理)
void startGame() {
  score = 0;
  escaped = 0;
  spawnTimer = 0;
  projectileFlying = false;
  explosionTimer = 0;
  enemies.clear();

  aimXSlider.setValue(0.5);
  aimYSlider.setValue(0.5);

  changeScreen(SCREEN_GAME);
}

void retryGame() {
  startGame();
}

// 発射ボタン
void fire() {
  if (screen != SCREEN_GAME || projectileFlying) return;

  shotX = getAimX();
  shotY = getAimY();
  shotTimer = SHOT_DELAY;
  projectileFlying = true;
}

void gameOver() {
  changeScreen(SCREEN_RESULT);
}

void keyPressed() {
  if (screen == SCREEN_GAME) {
    if (key == ' ') fire();
  } else if (key == ' ' || key == ENTER) {
    startGame();   // START画面・RESULT画面どちらも同じ
  }
}


// ============================================================
// Enemyクラス
// ============================================================
class Enemy {
  // 生成した時点で出現位置・速度・大きさが決まる
  float x     = random(70, width - 70);
  float y     = random(-100, -30);
  float speed = random(1.5, 2.5);
  float size  = random(22, 32);

  void update() {
    y += speed/2;
  }

  void display() {
    noStroke();
    fill(220, 70, 70);
    ellipse(x, y, size, size);

    fill(255, 150, 100);
    ellipse(x, y, size * 0.45, size * 0.45);

    // 移動方向表示
    stroke(255, 100);
    line(x, y - size / 2, x, y - size);
  }
}
