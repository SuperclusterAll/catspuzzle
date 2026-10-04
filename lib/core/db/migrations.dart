/// 스키마 마이그레이션 목록.
///
/// 규칙: 이미 출시된 버전의 항목은 절대 수정하지 않는다.
/// 스키마를 바꿀 때는 리스트 끝에 새 버전을 추가한다.
/// 인덱스 0 = v1, 인덱스 1 = v2 ...
const List<List<String>> migrations = [
  // v1: 코어(재화, 고양이, 게임 진행도, 설정)
  [
    '''
    CREATE TABLE wallet (
      currency TEXT PRIMARY KEY,
      amount   INTEGER NOT NULL DEFAULT 0 CHECK (amount >= 0)
    )
    ''',
    // 재화 변동 이력. 게임별 획득량 밸런싱 분석 및 인플레 추적용.
    '''
    CREATE TABLE wallet_ledger (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      currency   TEXT    NOT NULL REFERENCES wallet(currency),
      delta      INTEGER NOT NULL,
      reason     TEXT    NOT NULL,
      source     TEXT,
      created_at INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_ledger_source ON wallet_ledger(source, created_at)',
    '''
    CREATE TABLE cats (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      breed_id    TEXT    NOT NULL,
      name        TEXT    NOT NULL,
      level       INTEGER NOT NULL DEFAULT 1,
      exp         INTEGER NOT NULL DEFAULT 0,
      affection   INTEGER NOT NULL DEFAULT 0,
      hunger      INTEGER NOT NULL DEFAULT 100,
      obtained_at INTEGER NOT NULL,
      last_fed_at INTEGER
    )
    ''',
    // 게임별 누적 기록 (무한 모드 최고점 등)
    '''
    CREATE TABLE game_progress (
      game_id     TEXT PRIMARY KEY,
      best_score  INTEGER NOT NULL DEFAULT 0,
      play_count  INTEGER NOT NULL DEFAULT 0,
      updated_at  INTEGER NOT NULL
    )
    ''',
    // 레벨형 게임(캣타워 소트, 털실 풀기 등)의 레벨별 기록
    '''
    CREATE TABLE level_progress (
      game_id    TEXT    NOT NULL,
      level      INTEGER NOT NULL,
      stars      INTEGER NOT NULL DEFAULT 0,
      best_score INTEGER NOT NULL DEFAULT 0,
      cleared_at INTEGER NOT NULL,
      PRIMARY KEY (game_id, level)
    )
    ''',
    '''
    CREATE TABLE settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
    "INSERT INTO wallet (currency, amount) VALUES ('cash', 0), ('bungeoppang', 0)",
  ],
  // v2: 도감, 아이템 인벤토리
  [
    // 게임별 도감. entry_id는 게임 모듈이 정한다 (예: 냥냥 합체 't3_tuxedo').
    '''
    CREATE TABLE codex (
      game_id  TEXT    NOT NULL,
      entry_id TEXT    NOT NULL,
      first_at INTEGER NOT NULL,
      PRIMARY KEY (game_id, entry_id)
    )
    ''',
    '''
    CREATE TABLE inventory (
      item_id TEXT    PRIMARY KEY,
      count   INTEGER NOT NULL DEFAULT 0 CHECK (count >= 0)
    )
    ''',
    // 신규/기존 유저 모두에게 체험용 아이템 지급
    "INSERT INTO inventory (item_id, count) VALUES ('churu', 2), ('cucumber', 2)",
  ],
];

int get latestSchemaVersion => migrations.length;
