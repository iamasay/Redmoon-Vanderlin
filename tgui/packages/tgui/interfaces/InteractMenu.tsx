// tgui/packages/tgui/interfaces/InteractMenu.tsx

import { useState } from 'react';
import {
  Box,
  Button,
  ProgressBar,
  Section,
  Stack,
  ByondUi,
} from 'tgui-core/components';
import { Window } from '../layouts';
import { useBackend } from '../backend';

type TabId = 'main' | 'builder';

const BODY_PART_LABELS: Record<BodyPartId, string> = {
  head: 'Голова',
  chest: 'Торс',
  groin: 'Пах',
  left_arm: 'Левая рука',
  right_arm: 'Правая рука',
  left_leg: 'Левая нога',
  right_leg: 'Правая нога',
  tail: 'Хвост',
};

type BodyPartId =
  | 'head'
  | 'chest'
  | 'groin'
  | 'left_arm'
  | 'right_arm'
  | 'left_leg'
  | 'right_leg'
  | 'tail';

const INTERACTION_NORMAL = 0;
const INTERACTION_LEWD = 1;
const INTERACTION_EXTREME = 2;
const INTERACTION_UNHOLY = 3;

interface InteractionAction {
  id: string;
  name: string;
  type?: number;
  is_favorite?: boolean;
}

type InteractionActionsByPart = {
  [K in BodyPartId]?: InteractionAction[];
};

interface InteractMenuData {
  entity_from: string;
  entity_to: string;
  character_ref: unknown;
  actions_by_part: InteractionActionsByPart;
  favorite_interactions?: string[];
}

const getInteractionColor = (type = INTERACTION_NORMAL) => {
  switch (type) {
    case INTERACTION_EXTREME:
      return 'red';
    case INTERACTION_UNHOLY:
      return 'orange';
    case INTERACTION_LEWD:
      return 'pink';
    default:
      return 'default';
  }
};

const isFavorite = (
  action: InteractionAction,
  favorites: string[] = [],
) => {
  if (action.is_favorite) {
    return true;
  }
  return favorites.includes(action.id);
};

export const InteractMenu = (props, context) => {
  const { data, config, act } = useBackend<InteractMenuData>();
  const { entity_from, entity_to, character_ref, favorite_interactions = [] } =
    data;

  const [selectedPart, setSelectedPart] = useState<BodyPartId>('chest');
  const [activeTab, setActiveTab] = useState<TabId>('main');
  const [showFavoritesOnly, setShowFavoritesOnly] = useState(false);
  const [duration, setDuration] = useState(0.0);

  const progressValue = 50;

  const handleMouseOver = (e: React.MouseEvent<HTMLDivElement>) => {
    e.currentTarget.style.border = '2px solid #fff';
  };

  const handleMouseLeave = (e: React.MouseEvent<HTMLDivElement>) => {
    e.currentTarget.style.border = '2px solid transparent';
  };

  if (config.status < 2) {
    return null;
  }

  const baseActions = data.actions_by_part?.[selectedPart] || [];
  const actions = showFavoritesOnly
    ? baseActions.filter((action) =>
        isFavorite(action, favorite_interactions),
      )
    : baseActions;

  return (
    <Window title="Взаимодействие с телом" width={1000} height={800}>
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item>
            <Section>
              <Stack vertical>
                <Stack.Item>
                  <Box textAlign="center" bold>
                    {(entity_from || 'Сущность 1') +
                      ' --> ' +
                      (entity_to || 'Сущность 2')}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <ProgressBar
                    value={progressValue}
                    minValue={0}
                    maxValue={100}
                  />
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Stack>
              <Stack.Item>
                <Button
                  selected={activeTab === 'main'}
                  onClick={() => setActiveTab('main')}
                >
                  Основное
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  selected={activeTab === 'builder'}
                  onClick={() => setActiveTab('builder')}
                >
                  Конструктор
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>

          <Stack.Item grow>
            {activeTab === 'main' ? (
              <Stack fill>
                <Stack.Item grow={0}>
                  <Section title="Тело" textAlign="center">
                    <Stack vertical align="center">
                      <Stack.Item>
                        <Box
                          position="relative"
                          style={{
                            width: '128px',
                            height: '128px',
                            margin: '0 auto',
                          }}
                        >
                          <ByondUi
                            height="128px"
                            width="128px"
                            params={{ id: character_ref, type: 'map' }}
                          />
                        </Box>
                      </Stack.Item>

                      <Stack.Item>
                        <Box
                          position="relative"
                          style={{
                            width: '128px',
                            height: '128px',
                            marginTop: '30px',
                            marginLeft: '20x',
                            marginRight: 'auto',
                            background: 'rgba(0, 0, 0, 0.6)',
                          }}
                        >
                          <Box
                            position="absolute"
                            style={{
                              background:
                                selectedPart === 'head'
                                  ? 'rgba(255, 255, 255, 0.9)'
                                  : 'rgba(255, 255, 255, 0.4)',
                              left: '40%',
                              top: '7%',
                              width: '20%',
                              height: '20%',
                              clipPath:
                                'polygon(50% 0%, 100% 40%, 80% 100%, 20% 100%, 0% 40%)',
                              cursor: 'pointer',
                            }}
                            onClick={() => setSelectedPart('head')}
                            onMouseOver={handleMouseOver}
                            onMouseLeave={handleMouseLeave}
                          />

                          <Box
                            position="absolute"
                            style={{
                              background:
                                selectedPart === 'chest'
                                  ? 'rgba(255, 255, 255, 0.9)'
                                  : 'rgba(255, 255, 255, 0.4)',
                              left: '35%',
                              top: '30%',
                              width: '30%',
                              height: '25%',
                              borderRadius: '20%',
                              cursor: 'pointer',
                            }}
                            onClick={() => setSelectedPart('chest')}
                            onMouseOver={handleMouseOver}
                            onMouseLeave={handleMouseLeave}
                          />

                          <Box
                            position="absolute"
                            style={{
                              background:
                                selectedPart === 'groin'
                                  ? 'rgba(255, 255, 255, 0.9)'
                                  : 'rgba(255, 255, 255, 0.4)',
                              left: '36%',
                              top: '55%',
                              width: '28%',
                              height: '15%',
                              borderRadius: '20%',
                              cursor: 'pointer',
                            }}
                            onClick={() => setSelectedPart('groin')}
                            onMouseOver={handleMouseOver}
                            onMouseLeave={handleMouseLeave}
                          />

                          <Box
                            position="absolute"
                            style={{
                              background:
                                selectedPart === 'left_arm'
                                  ? 'rgba(255, 255, 255, 0.9)'
                                  : 'rgba(255, 255, 255, 0.4)',
                              left: '25%',
                              top: '34%',
                              width: '9%',
                              height: '30%',
                              cursor: 'pointer',
                            }}
                            onClick={() => setSelectedPart('left_arm')}
                            onMouseOver={handleMouseOver}
                            onMouseLeave={handleMouseLeave}
                          />

                          <Box
                            position="absolute"
                            style={{
                              background:
                                selectedPart === 'right_arm'
                                  ? 'rgba(255, 255, 255, 0.9)'
                                  : 'rgba(255, 255, 255, 0.4)',
                              right: '25%',
                              top: '34%',
                              width: '9%',
                              height: '30%',
                              cursor: 'pointer',
                            }}
                            onClick={() => setSelectedPart('right_arm')}
                            onMouseOver={handleMouseOver}
                            onMouseLeave={handleMouseLeave}
                          />

                          <Box
                            position="absolute"
                            style={{
                              background:
                                selectedPart === 'left_leg'
                                  ? 'rgba(255, 255, 255, 0.9)'
                                  : 'rgba(255, 255, 255, 0.4)',
                              left: '51%',
                              bottom: '-6%',
                              width: '12%',
                              height: '35%',
                              cursor: 'pointer',
                            }}
                            onClick={() => setSelectedPart('left_leg')}
                            onMouseOver={handleMouseOver}
                            onMouseLeave={handleMouseLeave}
                          />

                          <Box
                            position="absolute"
                            style={{
                              background:
                                selectedPart === 'right_leg'
                                  ? 'rgba(255, 255, 255, 0.9)'
                                  : 'rgba(255, 255, 255, 0.4)',
                              right: '51%',
                              bottom: '-6%',
                              width: '12%',
                              height: '35%',
                              cursor: 'pointer',
                            }}
                            onClick={() => setSelectedPart('right_leg')}
                            onMouseOver={handleMouseOver}
                            onMouseLeave={handleMouseLeave}
                          />

                          <Box
                            position="absolute"
                            style={{
                              background:
                                selectedPart === 'tail'
                                  ? 'rgba(255, 255, 255, 0.9)'
                                  : 'rgba(255, 255, 255, 0.4)',
                              right: '63%',
                              bottom: '-6%',
                              width: '34%',
                              height: '25%',
                              clipPath:
                                'polygon(100% 23%, 0% 100%, 100% 100%)',
                              cursor: 'pointer',
                            }}
                            onClick={() => setSelectedPart('tail')}
                            onMouseOver={handleMouseOver}
                            onMouseLeave={handleMouseLeave}
                          />
                        </Box>
                      </Stack.Item>
                    </Stack>
                  </Section>
                </Stack.Item>

                <Stack.Item grow={1}>
                  <Section
                    title={`Действия: ${BODY_PART_LABELS[selectedPart]}`}
                    fill
                    buttons={
                      <Button
                        icon="star"
                        selected={showFavoritesOnly}
                        tooltip="Показать только избранное"
                        onClick={() =>
                          setShowFavoritesOnly(!showFavoritesOnly)
                        }
                      />
                    }
                  >
                    {actions.length === 0 ? (
                      <Box color="label">
                        {showFavoritesOnly
                          ? 'Нет доступных избранных действий для этой части тела.'
                          : 'Нет доступных действий с учётом ваших префов и префов партнёра.'}
                      </Box>
                    ) : (
                      <Box
                        style={{
                          maxHeight: '500px',
                          overflowY: 'auto',
                        }}
                      >
                        <Stack vertical>
                          {actions.map((action) => {
                            const fav = isFavorite(
                              action,
                              favorite_interactions,
                            );
                            return (
                              <Stack.Item key={action.id}>
                                <Stack align="center">
                                  <Stack.Item>
                                    <Button
                                      icon="play"
                                      onClick={() =>
                                        act('run_action_once', {
                                          part: selectedPart,
                                          action_id: action.id,
                                          duration,
                                        })
                                      }
                                      width="24px"
                                    />
                                  </Stack.Item>

                                  <Stack.Item grow>
                                    <Button
                                      fluid
                                      color={getInteractionColor(action.type)}
                                      onClick={() =>
                                        act('run_action_once', {
                                          part: selectedPart,
                                          action_id: action.id,
                                          duration,
                                        })
                                      }
                                    >
                                      {action.name}
                                    </Button>
                                  </Stack.Item>

                                  <Stack.Item>
                                    <Button
                                      icon={fav ? 'star' : 'star-o'}
                                      selected={fav}
                                      onClick={() =>
                                        act('toggle_favorite', {
                                          action_id: action.id,
                                        })
                                      }
                                      width="24px"
                                    />
                                  </Stack.Item>
                                </Stack>
                              </Stack.Item>
                            );
                          })}
                        </Stack>
                      </Box>
                    )}
                  </Section>
                </Stack.Item>
              </Stack>
            ) : (
              <Section title="Конструктор действий" fill>
                <Stack vertical>
                  <Stack.Item>
                    <Box color="label">
                      Здесь будет конструктор действий для этого юзера.
                    </Box>
                  </Stack.Item>
                  <Stack.Item>
                    <Button icon="plus" onClick={() => null}>
                      Добавить новое действие
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Box color="label">
                      Пока это только визуальная заглушка без логики.
                    </Box>
                  </Stack.Item>
                </Stack>
              </Section>
            )}
          </Stack.Item>

          <Stack.Item>
            <Section title="Скорость автоматических действий" fill>
              <Stack align="center">
                <Stack.Item>
                  <Box width={6} textAlign="right">
                    {duration.toFixed(1)} с
                  </Box>
                </Stack.Item>
                <Stack.Item grow>
                  <input
                    type="range"
                    min={0}
                    max={4}
                    step={0.1}
                    value={duration}
                    style={{ width: '100%' }}
                    onChange={(e) => setDuration(Number(e.target.value))}
                  />
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
