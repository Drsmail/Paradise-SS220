import { useState } from 'react';
import { Box, Button, NoticeBox, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { CharacterPortraitPanel, type PortraitPanelData } from './CharacterPortraits/CharacterPortraitPanel';

type Data = PortraitPanelData & {
  upload_in_progress: BooleanLike;
};

export const CharacterPortraits = () => {
  const { act, data } = useBackend<Data>();
  const [showRequirements, setShowRequirements] = useState(false);

  return (
    <CharacterPortraitPanel
      data={data}
      listTitle="Мои изображения"
      onRefresh={() => act('refresh')}
      onSelect={(key) => act('select', { key })}
      title="Портреты персонажей"
    >
      {showRequirements && (
        <NoticeBox>
          <Box>Требования к изображению:</Box>
          <ul style={{ margin: 0, paddingLeft: '1.5em' }}>
            <li>PNG без анимации;</li>
            <li>не более 10 MiB и 2048×2048 пикселей;</li>
            <li>не более двух изображений на модерации или одобренных;</li>
            <li>имя файла не должно совпадать с уже загруженным.</li>
          </ul>
        </NoticeBox>
      )}
      <Stack>
        <Stack.Item grow>
          <Button
            fluid
            color="good"
            disabled={!data.service_configured || !!data.upload_in_progress}
            icon="upload"
            onClick={() => act('upload')}
          >
            {data.upload_in_progress ? 'Загрузка...' : 'Загрузить файл'}
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="info-circle"
            selected={showRequirements}
            onClick={() => setShowRequirements(!showRequirements)}
          >
            Info
          </Button>
        </Stack.Item>
      </Stack>
    </CharacterPortraitPanel>
  );
};
