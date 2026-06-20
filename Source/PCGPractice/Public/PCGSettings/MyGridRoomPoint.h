// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "PCGSettings.h"

#include "MyGridRoomPoint.generated.h"

UCLASS(MinimalAPI, BlueprintType, ClassGroup=(Procedural))
class UMyGridRoomPointSettings : public UPCGSettings
{
	GENERATED_BODY()

public:
	//~Begin UPCGSettings interface
#if WITH_EDITOR
	virtual FName GetDefaultNodeName() const override;
	virtual FText GetDefaultNodeTitle() const override;
	virtual FText GetNodeTooltipText() const override;
	virtual EPCGSettingsType GetType() const override { return EPCGSettingsType::Spatial; }
#endif //WITH_EDITOR

protected:
	virtual TArray<FPCGPinProperties> InputPinProperties() const override;
	virtual TArray<FPCGPinProperties> OutputPinProperties() const override;
	virtual FPCGElementPtr CreateElement() const override;
	//~End UPCGSettings interface

public:
	// 그리드 X 방향 셀 수
	UPROPERTY(BlueprintReadWrite, EditAnywhere, Category="GridRoom", meta=(ClampMin=1))
	int32 GridSizeX = 5;
	// 그리드 Y 방향 셀 수
	UPROPERTY(BlueprintReadWrite, EditAnywhere, Category="GridRoom", meta=(ClampMin=1))
	int32 GridSizeY = 5;
	// 셀 하나의 크기 (언리얼 단위, cm)
	UPROPERTY(BlueprintReadWrite, EditAnywhere, Category="GridRoom", meta=(ClampMin=1.0f))
	float CellSize = 200.0f;
};

// FSimplePCGElement: 캐시·재진입 처리를 자동화하는 PCG 엘리먼트 기반 클래스
class FMyGridRoomPointElement : public IPCGElement
{
protected:
	virtual bool ExecuteInternal(FPCGContext* Context) const override;
};
