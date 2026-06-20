// Fill out your copyright notice in the Description page of Project Settings.

#include "Public/PCGSettings/MyGridRoomPoint.h"
#include "PCGContext.h"
#include "PCGPin.h"
#include "Data/PCGPointData.h"
#include "Helpers/PCGHelpers.h"

#define LOCTEXT_NAMESPACE "MyGridRoomPointElement"

#if WITH_EDITOR
FName UMyGridRoomPointSettings::GetDefaultNodeName() const
{
	return FName(TEXT("MyGridRoomPoint"));
}

FText UMyGridRoomPointSettings::GetDefaultNodeTitle() const
{
	return LOCTEXT("NodeTitle", "PCG Grid Room Point");
}

FText UMyGridRoomPointSettings::GetNodeTooltipText() const
{
	return LOCTEXT("NodeTooltip", "그리드 좌표계 기반으로 방 배치용 포인트를 생성합니다.");
}
#endif //WITH_EDITOR

TArray<FPCGPinProperties> UMyGridRoomPointSettings::InputPinProperties() const
{
	// 이 노드는 입력 없이 포인트를 직접 생성하므로 빈 배열 반환
	return TArray<FPCGPinProperties>();
}

TArray<FPCGPinProperties> UMyGridRoomPointSettings::OutputPinProperties() const
{
	// 기본 출력 레이블로 Point 타입 핀 하나 등록
	TArray<FPCGPinProperties> Props;
	Props.Emplace(PCGPinConstants::DefaultOutputLabel, EPCGDataType::Point);
	return Props;
}

FPCGElementPtr UMyGridRoomPointSettings::CreateElement() const
{
	return MakeShared<FMyGridRoomPointElement>();
}

bool FMyGridRoomPointElement::ExecuteInternal(FPCGContext* Context) const
{
	//Unreal Insights에서 프로파일링 데이터를 수집하도록 마킹
	TRACE_CPUPROFILER_EVENT_SCOPE(FMyGridRoomPointElement::Execute);

	check(Context);

	// Settings에서 그리드 파라미터 읽기
	const UMyGridRoomPointSettings* Settings = Context->GetInputSettings<UMyGridRoomPointSettings>();
	check(Settings);

	const int32 GridSizeX = Settings->GridSizeX;
	const int32 GridSizeY = Settings->GridSizeY;
	const float CellSize  = Settings->CellSize;

	// 새 포인트 데이터 생성 — 입력 데이터를 직접 수정하지 않도록 임시 메모리공간 통해 생성(GetTransientPackage())
	UPCGPointData* OutputPointData = NewObject<UPCGPointData>(GetTransientPackage());

	TArray<FPCGPoint> Points;
	// 재할당 문제가 발생하지않게 미리 공간 확보.
	Points.Reserve(GridSizeX * GridSizeY);

	// 그리드 좌표를 월드 위치로 변환하여 포인트 배열 생성
	// 0부터 GridSizeX-1, GridSizeY-1까지 순회하면서 FPCGPoint를 하나씩 만들기.
	for (int32 X = 0; X < GridSizeX; ++X)
	{
		for (int32 Y = 0; Y < GridSizeY; ++Y)
		{
			FPCGPoint Point;
			Point.Transform.SetLocation(FVector(X * CellSize, Y * CellSize, 0.0f));
			// Density 미설정(0) 시 필터 노드에서 제거되므로 반드시 1로 설정
			Point.Density = 1.0f;
			// 좌표 기반 해시값을 넣어 재현 가능한 시드 — 동일 그리드면 항상 동일한 결과
			Point.Seed = PCGHelpers::ComputeSeed(X, Y);
			Points.Add(Point);
		}
	}

	OutputPointData->SetPoints(Points);

	// 출력 핀에 데이터 등록
	FPCGTaggedData& Output = Context->OutputData.TaggedData.Emplace_GetRef();
	Output.Data = OutputPointData;
	Output.Pin  = PCGPinConstants::DefaultOutputLabel;

	return true;
}

#undef LOCTEXT_NAMESPACE
