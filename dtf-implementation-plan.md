# DTF v0.1 Implementation Plan

## Current State Analysis
The project currently has:
- 32x18 grid system with flexible sizing support
- Basic tower placement and management
- Wave-based enemy spawning system
- Simple pathfinding along predefined paths
- Resource/gold system
- UI framework for purchases and game state

## Implementation Phases

### Phase 1: Core Systems Enhancement

#### 1.1 Flag Implementation
1. Create `Flag` class:
```csharp
public class Flag : MonoBehaviour
{
    public float maxHealth;
    public float currentHealth;
    public event Action<float> OnHealthChanged;
    public event Action OnFlagDestroyed;
    
    private SpriteRenderer spriteRenderer;
    private HealthBar healthBar;
}
```
2. Add flag placement logic in `MapManager`
3. Create flag health UI component
4. Implement flag destruction game over state

#### 1.2 Wall System
1. Create `Wall` class inheriting from existing placement system:
```csharp
public class Wall : MonoBehaviour
{
    public float maxHealth;
    public float currentHealth;
    public WallType type;
    public int cost;
    
    private HealthBar healthBar;
    private SpriteRenderer spriteRenderer;
}
```
2. Extend `GridCell` to support wall placement
3. Add wall purchase UI to tower selection menu
4. Implement wall health visualization

#### 1.3 Enemy Enhancement
##### 1.3.a Basic Attack System
1. Create `IAttackable` interface:
```csharp
public interface IAttackable
{
    float CurrentHealth { get; }
    float MaxHealth { get; }
    bool CanBeAttacked { get; }
    void TakeDamage(float damage);
    Vector3 Position { get; }
}
```

2. Implement basic attack capability:
```csharp
public partial class Enemy
{
    public float attackDamage;
    public float attackRange;
    public float attackSpeed;
    private float attackCooldown;
    
    public void Attack(IAttackable target);
    private void UpdateAttackBehavior();
}
```

##### 1.3.b Target Selection and State Management
1. Implement target priority system:
```csharp
public class TargetPriority
{
    public float flagPriority = 1.0f;
    public float wallPriority = 0.8f;
    public float towerPriority = 0.6f;
    
    public IAttackable SelectTarget(List<IAttackable> potentialTargets);
}
```

2. Create state management system:
```csharp
public class EnemyStateManager
{
    private Dictionary<EnemyState, IEnemyState> states;
    private IEnemyState currentState;
    
    public void UpdateState();
    public void TransitionTo(EnemyState newState);
}
```

#### 1.4 Scoring System
1. Create `ScoreManager` class:
```csharp
public class ScoreManager : MonoBehaviour
{
    public static ScoreManager Instance { get; private set; }
    
    public float CurrentScore { get; private set; }
    public event Action<float> OnScoreChanged;
    
    private Dictionary<string, float> scoreMultipliers;
    
    public void AddScore(float basePoints, string multiplierCategory = "default");
    public void RegisterMultiplier(string category, float multiplier);
    public void ResetScore();
}
```

2. Create `ScoreData` ScriptableObject:
```csharp
[CreateAssetMenu(fileName = "ScoreData", menuName = "DTF/Score Data")]
public class ScoreData : ScriptableObject
{
    [System.Serializable]
    public class EnemyScoreData
    {
        public EnemyType enemyType;
        public float basePoints;
        public float bonusPointsPerWave;
    }
    
    public List<EnemyScoreData> enemyScores;
    public float comboMultiplierBase = 1.1f;
    public float comboTimeWindow = 5f;
}
```

3. Extend `Enemy` class with scoring:
```csharp
public partial class Enemy
{
    [SerializeField] private float baseScoreValue;
    private void AwardScore()
    {
        ScoreManager.Instance.AddScore(baseScoreValue);
    }
}
```

4. Add score UI component to top bar

#### 1.5 Game State Management
1. Create `GameStateManager`:
```csharp
public class GameStateManager : MonoBehaviour
{
    public static GameStateManager Instance { get; private set; }
    
    public GameState CurrentState { get; private set; }
    public event Action<GameState> OnGameStateChanged;
    
    private Dictionary<GameState, IGameStateHandler> stateHandlers;
    
    public void TransitionTo(GameState newState);
    public void PauseGame();
    public void ResumeGame();
    public void GameOver(bool victory);
}
```

2. Implement state transitions:
```csharp
public interface IGameStateHandler
{
    void EnterState();
    void UpdateState();
    void ExitState();
}
```

3. Create game over handling:
```csharp
public class GameOverHandler : IGameStateHandler
{
    public void ProcessGameOver(bool victory);
    public void SaveStatistics();
    public void ShowGameOverUI();
}
```

### Phase 2: Pathfinding & AI

#### 2.1 Enhanced Pathfinding
1. Implement optimized A* system:
```csharp
public class PathFinder
{
    private GridManager gridManager;
    private Dictionary<Vector2Int, PathNode> nodeCache;
    private HashSet<Vector2Int> dirtyNodes;
    
    public List<Vector2Int> CalculatePath(Vector2Int start, Vector2Int goal);
    private float CalculatePathCost(Vector2Int current, bool includeWalls);
    public void InvalidateCache(Vector2Int position);
    private void UpdateCache();
}
```

2. Add path caching:
```csharp
public class PathCache
{
    private Dictionary<PathKey, CachedPath> pathCache;
    private const int MAX_CACHE_SIZE = 1000;
    
    public List<Vector2Int> GetCachedPath(Vector2Int start, Vector2Int end);
    public void InvalidatePath(Vector2Int position);
    private void CleanCache();
}
```

#### 2.2 Enemy AI Behavior
1. Create behavior state machine:
```csharp
public enum EnemyState
{
    Pathfinding,
    AttackingWall,
    AttackingTower,
    AttackingFlag,
    Dead
}
```
2. Implement target priority system
3. Add different enemy types with varying behaviors
4. Create enemy buff/debuff system

### Phase 3: Wave System Enhancement

#### 3.1 Multiple Spawn Points
1. Extend `WaveManager` to support multiple spawn points:
```csharp
public class SpawnPoint
{
    public Vector2Int Position;
    public List<EnemyGroup> AssignedEnemies;
    public float SpawnDelay;
}
```
2. Create spawn point coordination system
3. Implement wave distribution logic
4. Add visual indicators for active spawn points

#### 3.2 Wave Configuration
1. Enhance wave data structure:
```csharp
public class WaveData
{
    public List<SpawnPoint> SpawnPoints;
    public List<EnemyGroup> EnemyGroups;
    public float WaveDuration;
    public float DifficultyMultiplier;
}
```
2. Create wave difficulty scaling system
3. Implement wave composition variety
4. Add between-wave bonus mechanics

### Phase 4: UI and Feedback

#### 4.1 Combat Feedback
1. Create damage number system
2. Implement attack range indicators
3. Add wall/tower health bars
4. Create status effect visualizations
5. Add score popup animations
6. Implement combo multiplier visualization

#### 4.2 Strategic UI
1. Enhance tower/wall placement preview
2. Add minimap for larger grid navigation
3. Implement wave information panel
4. Create resource forecasting UI
5. Add score breakdown panel (accessible during gameplay)
6. Create wave bonus score previews

#### 4.3 Resource Display
1. Enhance `ResourceDisplay`:
```csharp
public class ResourceDisplay : MonoBehaviour
{
    [SerializeField] private IconTextPair scoreDisplay;
    [SerializeField] private float scoreAnimationDuration = 0.5f;
    
    private void SetupScoreDisplay()
    {
        // Position between gold and wave display
        scoreDisplay.transform.SetSiblingIndex(1);
    }
    
    public void UpdateScore(float newScore, bool animate = true);
    private void AnimateScoreChange(float oldScore, float newScore);
}
```

### Phase 5: High Score System

#### 5.1 Score Persistence
1. Create `HighScoreEntry` structure:
```csharp
[System.Serializable]
public class HighScoreEntry
{
    public string playerName;
    public float score;
    public System.DateTime date;
    public int wavesCompleted;
    public Dictionary<string, int> statistics;
}
```

2. Implement `HighScoreManager`:
```csharp
public class HighScoreManager : MonoBehaviour
{
    public const int MaxEntries = 10;
    private List<HighScoreEntry> highScores;
    
    public void SubmitScore(HighScoreEntry entry);
    public void LoadHighScores();
    public void SaveHighScores();
    private bool IsHighScore(float score);
}
```

#### 5.2 High Score UI
1. Create high score submission UI:
- Name input field
- Score display
- Statistics summary
- Submit button

2. Create high score display UI:
- Scrollable leaderboard
- Entry animations
- Filtering options
- Personal best tracking

3. Implement score statistics tracking:
- Enemies defeated by type
- Waves completed
- Highest combo achieved
- Total gold earned

#### 5.3 Save System Integration
1. Create `SaveDataManager`:
```csharp
public class SaveDataManager : MonoBehaviour
{
    private const int CURRENT_VERSION = 1;
    
    public void SaveGameState(GameState state);
    public void SaveHighScores(List<HighScoreEntry> scores);
    public bool ValidateSaveData();
    private void MigrateSaveData(int fromVersion);
    public void AutoSave();
}
```

2. Implement data versioning:
```csharp
[System.Serializable]
public class SaveData
{
    public int version;
    public List<HighScoreEntry> highScores;
    public Dictionary<string, object> gameState;
    public Dictionary<string, object> statistics;
}
```

## Implementation Order and Dependencies

### Week 1
- Flag implementation
- Basic wall system
- Enemy attack capability
- IAttackable interface
- Basic scoring system
- Score UI integration

### Week 2
- Enhanced pathfinding
- Enemy AI state machine
- Multiple spawn points
- Wave system updates
- Enhanced scoring features
- Combo system implementation

### Week 3
- UI enhancements
- Combat feedback
- Bug fixes and polish
- Performance optimization
- High score system
- Score persistence
- Leaderboard UI

## Technical Considerations

### Performance Optimization
1. Implement object pooling for:
- Enemies
- Projectiles
- Visual effects
- Damage numbers

2. Optimize pathfinding:
- Path caching
- Batch updates
- Grid sector optimization

3. Memory management:
- Proper cleanup of destroyed objects
- Event system optimization
- Resource unloading

4. Grid Optimizations:
```csharp
public class GridOptimizer
{
    private Dictionary<Vector2Int, List<IGridEntity>> spatialMap;
    private const int PARTITION_SIZE = 4;
    
    public List<IGridEntity> GetNearbyEntities(Vector2Int position, int radius);
    public void UpdateEntity(IGridEntity entity);
    private void RebuildSpatialMap();
}
```

### Resource Management
1. Asset Management:
```csharp
public class AssetManager : MonoBehaviour
{
    private Dictionary<string, AssetBundle> loadedBundles;
    private Dictionary<string, HashSet<string>> sceneAssetDependencies;
    
    public T LoadAsset<T>(string assetName) where T : UnityEngine.Object;
    public void PreloadScene(string sceneName);
    public void UnloadUnusedAssets();
}
```

### Event System Architecture
1. Create ScriptableObject events:
```csharp
[CreateAssetMenu(fileName = "GameEvent", menuName = "DTF/Events/GameEvent")]
public class GameEvent : ScriptableObject
{
    private List<GameEventListener> listeners = new List<GameEventListener>();
    
    public void Raise();
    public void RegisterListener(GameEventListener listener);
    public void UnregisterListener(GameEventListener listener);
}
```

### Scene Management
1. Create scene manager:
```csharp
public class SceneTransitionManager : MonoBehaviour
{
    public event Action<float> OnLoadingProgressChanged;
    
    public async Task LoadSceneAsync(string sceneName);
    public void ShowLoadingScreen();
    private void CleanupCurrentScene();
    public void PersistHighScores();
}
```

## Testing Strategy

### Unit Tests
1. Pathfinding algorithms
2. Damage calculations
3. Wave spawning logic
4. Resource management

### Integration Tests
1. Enemy-Wall interactions
2. Tower-Enemy combat
3. Wave progression
4. Save/Load system

### Performance Tests
1. Large enemy counts
2. Multiple pathfinding requests
3. Complex wave configurations
4. UI update frequency

### Stress Tests
1. Maximum Enemy Count:
- Test with 100, 500, and 1000 simultaneous enemies
- Monitor frame rate and memory usage
- Test pathfinding performance at scale

2. Wall Coverage:
- Test pathfinding with 25%, 50%, 75% wall coverage
- Measure path calculation times
- Test path recalculation with wall destruction

3. UI Performance:
- Test score animations with rapid updates
- Measure UI rebuild times
- Test with multiple simultaneous popups

4. Save System:
- Test with corrupted save data
- Measure save/load times with large datasets
- Test auto-save performance impact

## Future-Proofing Considerations

### Extensibility
1. Design systems to support:
- Hero units
- NPC allies
- Research system
- Veteran tower system
- Multiple game modes

### Modularity
1. Keep systems loosely coupled
2. Use interface-based communication
3. Implement proper dependency injection
4. Create flexible configuration system

## Documentation Requirements

### Code Documentation
1. XML comments for public APIs
2. Architecture diagrams
3. System interaction documentation
4. Performance guidelines

### API Documentation
1. Scoring System Integration:
- Event system usage
- Custom score type implementation
- Score animation customization

2. Save Data Format:
- Data structure documentation
- Version migration guide
- Validation requirements

3. Performance Guidelines:
- Grid optimization best practices
- Event system usage patterns
- Asset loading recommendations

4. UI Customization:
- Theme system usage
- Custom animation implementation
- Layout modification guide

### User Documentation
1. Tutorial system design
2. UI element descriptions
3. Game mechanics explanation
4. Strategy guides framework 